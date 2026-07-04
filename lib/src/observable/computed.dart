import 'package:flutter/foundation.dart';

import '../core/batch_scope.dart';
import '../core/dependency_tracker.dart';
import '../core/listener_registry.dart';
import '../core/typedefs.dart';
import '../logging/observer_logger.dart';
import 'observable_subscription.dart';

/// A read-only [ValueListenable] whose value is derived from other
/// observables via [compute], reusing the same stack-based
/// [DependencyTracker] that [Observer] uses — no separate tracking
/// mechanism.
///
/// Lazy: [compute] never runs before the first read of [value]. Memoized:
/// subsequent reads return the cached value without recomputing, until a
/// dependency notifies. Only notifies its own listeners when the
/// recomputed value actually differs (`==`) from the previous one, so a
/// dependency changing without affecting the derived result causes no
/// downstream rebuild. Supports dynamic/conditional dependencies: an `if`
/// inside [compute] that reads a different observable on each run is
/// tracked correctly, exactly like inside an [Observer] builder.
///
/// Um [ValueListenable] somente leitura cujo valor é derivado de outros
/// observáveis via [compute], reaproveitando o mesmo [DependencyTracker]
/// baseado em pilha que o [Observer] usa — nenhum mecanismo de
/// rastreamento separado.
///
/// Preguiçoso (lazy): [compute] nunca roda antes da primeira leitura de
/// [value]. Memoizado: leituras subsequentes retornam o valor em cache sem
/// recalcular, até que uma dependência notifique. Só notifica seus
/// próprios listeners quando o valor recalculado realmente difere (`==`)
/// do anterior, então uma dependência que muda sem afetar o resultado
/// derivado não causa rebuild a jusante. Suporta dependências
/// dinâmicas/condicionais: um `if` dentro de [compute] que lê um
/// observável diferente a cada execução é rastreado corretamente, assim
/// como dentro do builder de um [Observer].
///
/// **Diamond glitch**: outside an active `Observable.batch()`, a diamond
/// dependency graph (two `Computed`s both derived from the same source,
/// and a third depending on both) can observe one recompute per changed
/// upstream branch, and — briefly, between those recomputes — a downstream
/// listener may run with one branch already updated and the other still
/// stale. Wrapping the writes that feed such a graph in
/// `Observable.batch()` avoids this: recompute is deferred to flush time
/// inside an active batch, so every affected `Computed` sees a fully
/// consistent set of upstream values and recomputes at most once. See
/// "Known limitations" in the README for a worked example.
///
/// **Glitch do diamante**: fora de um `Observable.batch()` ativo, um grafo
/// de dependências em diamante (dois `Computed` derivados da mesma origem,
/// e um terceiro dependendo de ambos) pode observar um recompute por ramo
/// alterado, e — brevemente, entre esses recomputes — um listener a
/// jusante pode rodar com um ramo já atualizado e o outro ainda
/// desatualizado. Envolver as escritas que alimentam esse grafo em
/// `Observable.batch()` evita isso: o recompute é adiado até o flush
/// dentro de um batch ativo, então todo `Computed` afetado enxerga um
/// conjunto totalmente consistente de valores a montante e recalcula no
/// máximo uma vez. Veja "Known limitations" no README para um exemplo
/// trabalhado.
///
/// Example / Exemplo:
/// ```dart
/// final firstName = 'Carlos'.obs;
/// final lastName = 'Castro'.obs;
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
/// Observer(() => Text(fullName.value)); // recomputes only when needed
/// ```
class Computed<T> implements ValueListenable<T> {
  /// Creates a [Computed] that derives its value by running [compute]. An
  /// optional [name] is used in debug logs. [compute] does not run until
  /// [value] is first read.
  ///
  /// [equals] overrides the default `==` comparison used to decide whether
  /// a recomputed value actually changed (and therefore should notify).
  /// Useful for types whose `==` is not meaningful for this purpose (e.g.
  /// comparing only a subset of fields, or floating-point values within a
  /// tolerance). Defaults to `(a, b) => a == b`.
  ///
  /// Cria um [Computed] que deriva seu valor executando [compute]. Um
  /// [name] opcional é usado nos logs de debug. [compute] não roda até que
  /// [value] seja lido pela primeira vez.
  ///
  /// [equals] sobrescreve a comparação `==` padrão usada para decidir se um
  /// valor recalculado realmente mudou (e, portanto, deve notificar). Útil
  /// para tipos cujo `==` não é significativo para este propósito (ex.:
  /// comparar apenas um subconjunto de campos, ou valores de ponto
  /// flutuante dentro de uma tolerância). Padrão: `(a, b) => a == b`.
  Computed(this._compute, {String? name, bool Function(T a, T b)? equals})
    : _name = name,
      _equals = equals ?? _defaultEquals;

  static bool _defaultEquals<T>(T a, T b) => a == b;

  final T Function() _compute;
  final String? _name;
  final bool Function(T a, T b) _equals;
  final ListenerRegistry _registry = ListenerRegistry();

  bool _hasValue = false;
  late T _value;
  List<Disposer> _dependencyDisposers = <Disposer>[];
  bool _isClosed = false;
  bool _dirty = false;

  String get _label => 'Computed(${_name ?? '#$hashCode'})';

  /// Whether [close] has already been called.
  ///
  /// Se [close] já foi chamado.
  bool get isClosed => _isClosed;

  @override
  T get value {
    DependencyTracker.reportRead(_registry, label: _label);
    _ensureLive();
    // A dependency changed while a batch was active: [_onDependencyChanged]
    // deferred the actual recompute to this read (or to the end-of-batch
    // flush, whichever comes first) instead of running it eagerly, so
    // every dependency this Computed reads is guaranteed to already hold
    // its final, post-batch value — never a partially-applied intermediate
    // one. See the "diamond glitch" note on the class doc.
    _flushIfDirty();
    return _value;
  }

  /// Forces the first [compute] run (and, with it, the subscription to the
  /// current dependencies) if it hasn't happened yet. No-op afterwards.
  ///
  /// Called both from [value] and from [addListener]/[listen], so that a
  /// listener registered *before* the value is ever read still gets
  /// notified of future dependency changes — matching the usual
  /// [ValueListenable] contract, where you may listen before reading.
  ///
  /// Força a primeira execução de [compute] (e, com ela, a inscrição nas
  /// dependências atuais) caso ainda não tenha ocorrido. Não faz nada depois
  /// disso.
  ///
  /// Chamado tanto por [value] quanto por [addListener]/[listen], para que
  /// um listener registrado *antes* de qualquer leitura do valor ainda seja
  /// notificado de futuras mudanças de dependência — seguindo o contrato
  /// usual de [ValueListenable], em que é possível escutar antes de ler.
  void _ensureLive() {
    if (!_hasValue) {
      _recompute();
    }
  }

  void _recompute() {
    _clearDependencies();
    final TrackingContext context = TrackingContext(_onDependencyChanged);
    try {
      final T newValue = DependencyTracker.track(context, _compute);
      // Compare against the still-valid previous value/flag *before*
      // overwriting either. `_hasValue` is only ever cleared by nothing but
      // the constructor's initial state here — dependency-triggered
      // recomputes never reset it — so this is a plain "did the derived
      // value change" check, not "is this the very first compute".
      final bool changed = !_hasValue || !_equals(_value, newValue);
      _hasValue = true;
      _value = newValue;
      if (changed) {
        _registry.notifyOrQueue();
      }
    } finally {
      // Re-subscribe to whatever dependencies [_compute] read this pass —
      // even if it threw partway through — instead of only doing so on a
      // successful return. Without this, a [_compute] that throws would
      // leave this Computed permanently unsubscribed from every dependency
      // (since [_clearDependencies] already tore down the old subscriptions
      // above), so it would never get a chance to recompute again even
      // after whatever condition caused the failure is fixed. The caller
      // (either [ListenerRegistry.notifyAll]'s per-listener `catch`, when
      // triggered eagerly outside a batch, or [BatchScope]'s own per
      // -callback `catch`, when deferred inside one) is still responsible
      // for catching and reporting the exception itself — this `finally`
      // only guarantees the dependency bookkeeping isn't lost alongside it.
      //
      // Reinscreve nas dependências que [_compute] leu nesta passagem —
      // mesmo que tenha lançado no meio do caminho — em vez de fazer isso
      // apenas em um retorno bem-sucedido. Sem isso, um [_compute] que
      // lança deixaria este Computed permanentemente sem inscrição em
      // nenhuma dependência (já que [_clearDependencies] já desfez as
      // inscrições antigas acima), então ele nunca teria chance de
      // recalcular de novo mesmo depois que a causa da falha fosse
      // corrigida. Quem chamou (o `catch` por listener de
      // [ListenerRegistry.notifyAll], quando disparado avidamente fora de
      // um batch, ou o `catch` por callback do próprio [BatchScope], quando
      // adiado dentro de um) continua responsável por capturar e reportar a
      // exceção em si — este `finally` só garante que a contabilidade de
      // dependências não se perca junto.
      _dependencyDisposers = context.disposers;
    }
  }

  // Note on laziness: only the *first* compute is lazy (deferred to the
  // first `value` read). Once a dependency has been read at least once,
  // subsequent dependency changes recompute eagerly right here, because
  // this Computed must know the new value immediately in order to decide
  // whether it actually changed and therefore whether to notify its own
  // listeners. A "lazy after every change" variant would need to notify
  // unconditionally (defeating the change-filtering guarantee) or defer
  // its own notification until the next external read (which existing
  // listeners like `ever`/`Observer` never perform on their own).
  //
  // Exception: while an `Observable.batch()` is active, this recompute is
  // deferred to the next `value` read (see the `_dirty` check there)
  // instead of running here immediately. This is what mitigates the
  // diamond-glitch case: if two of this batch's writes each feed a
  // different upstream branch of the same diamond, recomputing eagerly
  // here — once per branch, mid-batch — could momentarily mix one already
  // -updated branch with one still-stale one. Deferring until the batch
  // has fully flushed means every dependency read during the eventual
  // recompute already holds its final value.
  //
  // Nota sobre laziness: apenas o *primeiro* cálculo é preguiçoso (adiado
  // até a primeira leitura de `value`). Uma vez que uma dependência já foi
  // lida ao menos uma vez, mudanças subsequentes de dependência recalculam
  // imediatamente aqui, pois este Computed precisa saber o novo valor de
  // imediato para decidir se ele realmente mudou e, portanto, se deve
  // notificar seus próprios listeners.
  //
  // Exceção: enquanto um `Observable.batch()` está ativo, este recompute é
  // adiado até a próxima leitura de `value` (ver a checagem de `_dirty`
  // lá) em vez de rodar aqui imediatamente. Isso é o que mitiga o caso do
  // glitch do diamante: se duas escritas deste batch alimentarem ramos
  // diferentes do mesmo diamante, recalcular avidamente aqui — uma vez por
  // ramo, no meio do batch — poderia momentaneamente misturar um ramo já
  // atualizado com outro ainda desatualizado. Adiar até o batch ter sido
  // totalmente esvaziado garante que toda dependência lida durante o
  // eventual recompute já contenha seu valor final.
  void _onDependencyChanged() {
    if (_isClosed) {
      return;
    }
    if (BatchScope.isActive) {
      if (!_dirty) {
        _dirty = true;
        // Also flush (recompute + notify, if changed) once at the end of
        // this batch even if nobody reads `value` again meanwhile — so
        // this Computed's own listeners (an Observer, another Computed, an
        // `ever`) still get notified after the batch, exactly like they
        // would outside a batch. If `value` *is* read first (inside the
        // batch, before flush), the getter's own `_dirty` check already
        // recomputes eagerly there and this callback becomes a harmless
        // no-op (guarded by `_dirty` being false again by then).
        BatchScope.queueDirtyFlush(_flushIfDirty);
      }
      return;
    }
    _recompute();
  }

  void _flushIfDirty() {
    if (_isClosed || !_dirty) {
      return;
    }
    _dirty = false;
    _recompute();
  }

  void _clearDependencies() {
    for (final Disposer dispose in _dependencyDisposers) {
      dispose();
    }
    _dependencyDisposers = <Disposer>[];
  }

  @override
  void addListener(VoidCallback listener) {
    _ensureLive();
    _registry.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) => _registry.remove(listener);

  /// Subscribes [callback] to future recomputed values, mirroring
  /// `Observable.listen`.
  ///
  /// Inscreve [callback] para valores recalculados futuros, espelhando
  /// `Observable.listen`.
  ObservableSubscription listen(void Function(T value) callback) {
    _ensureLive();
    void listener() => callback(value);
    final Disposer dispose = _registry.add(listener);
    return ObservableSubscription.fromDisposer(dispose);
  }

  /// Disposes this [Computed]: unsubscribes from all current dependencies
  /// and clears its own listeners. Safe to call more than once.
  ///
  /// Descarta este [Computed]: cancela a inscrição em todas as dependências
  /// atuais e limpa seus próprios listeners. Seguro chamar mais de uma vez.
  void close() {
    if (_isClosed) {
      return;
    }
    _clearDependencies();
    final int removed = _registry.length;
    _registry.clear();
    _isClosed = true;
    if (kDebugMode) {
      ObserverLogger.disposed(_label, removed);
    }
  }
}
