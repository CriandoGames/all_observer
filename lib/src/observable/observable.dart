import 'package:all_observer/src/core/typedefs.dart';
import 'package:flutter/foundation.dart';

import '../core/batch_scope.dart';
import '../core/core_observable.dart';
import '../protocol/observer_protocol_event.dart';
import '../core/dependency_tracker.dart';
import '../logging/observer_config.dart';
import '../logging/observer_logger.dart';
import 'observable_subscription.dart';

/// A reactive holder of a value of type [T].
///
/// Reading [value] inside an [Observer] builder automatically registers
/// that Observer to rebuild when the value changes. [Observable] also
/// implements [ValueListenable], so it is directly usable with
/// [ValueListenableBuilder], `Listenable.merge`, or [AnimatedBuilder]
/// without any adapter.
///
/// Notification semantics are intentionally simple: a write only notifies
/// listeners when the new value is different from the current one
/// (`!=`). For mutable objects whose internal state changed without
/// replacing the reference, call [refresh] to force a notification.
///
/// Um contêiner reativo de um valor do tipo [T].
///
/// Ler [value] dentro do builder de um [Observer] registra automaticamente
/// aquele Observer para reconstruir quando o valor mudar. [Observable]
/// também implementa [ValueListenable], portanto é utilizável diretamente
/// com [ValueListenableBuilder], `Listenable.merge` ou [AnimatedBuilder]
/// sem nenhum adaptador.
///
/// A semântica de notificação é propositalmente simples: uma escrita só
/// notifica os listeners quando o novo valor é diferente do atual (`!=`).
/// Para objetos mutáveis cujo estado interno mudou sem substituir a
/// referência, chame [refresh] para forçar uma notificação.
///
/// **Isolate safety**: like the rest of Dart, an [Observable] is confined
/// to the isolate that created it. Writing to it from a different isolate
/// (e.g. via a raw `Isolate.spawn`, not `compute`/`Isolate.run` which copy
/// data instead of sharing references) does not work — there is no
/// cross-isolate synchronization here, by design; use
/// [SendPort]/[ReceivePort] or `compute` to move data between isolates and
/// write to the observable back on its own isolate.
///
/// **Segurança entre isolates**: como o restante do Dart, um [Observable]
/// é confinado ao isolate que o criou. Escrever nele a partir de um
/// isolate diferente (ex.: via `Isolate.spawn` bruto, não `compute`/
/// `Isolate.run`, que copiam dados em vez de compartilhar referências) não
/// funciona — não há sincronização entre isolates aqui, por design; use
/// [SendPort]/[ReceivePort] ou `compute` para mover dados entre isolates e
/// escreva no observável de volta no seu próprio isolate.
///
/// Example / Exemplo:
/// ```dart
/// final count = 0.obs;
/// Observer(() => Text('${count.value}'));
/// count.value++;
/// ```
class Observable<T> implements ValueListenable<T> {
  /// Creates an observable holding [initialValue]. An optional [name] is
  /// used in debug logs and warnings; when omitted, a short hash-based
  /// label is used instead.
  ///
  /// [equals] overrides the default `==` comparison used to decide whether
  /// a write actually changed the value (and therefore should notify).
  /// Useful for types whose `==` is not meaningful for this purpose (e.g.
  /// comparing only a subset of fields, or floating-point values within a
  /// tolerance). Defaults to `(a, b) => a == b`.
  ///
  /// Cria um observável contendo [initialValue]. Um [name] opcional é
  /// usado nos logs e warnings de debug; quando omitido, um rótulo curto
  /// baseado no hash é usado.
  ///
  /// [equals] sobrescreve a comparação `==` padrão usada para decidir se
  /// uma escrita realmente mudou o valor (e, portanto, deve notificar).
  /// Útil para tipos cujo `==` não é significativo para este propósito
  /// (ex.: comparar apenas um subconjunto de campos, ou valores de ponto
  /// flutuante dentro de uma tolerância). Padrão: `(a, b) => a == b`.
  Observable(T initialValue, {String? name, bool Function(T a, T b)? equals})
    : _core = CoreObservable<T>(initialValue, name: name, equals: equals) {
    // dispatch: false — CoreObservable's constructor already dispatched
    // ObserverInspector.onCreate; this call is console-printing only.
    if (kDebugMode) {
      ObserverLogger.created(_label, initialValue, dispatch: false);
    }
  }

  /// Runs [action], coalescing every [Observable]/collection write inside
  /// it so each distinct changed one notifies its manual [listen]/`ever`
  /// listeners exactly once, after [action] returns — writes still apply
  /// immediately, only the *notification* is deferred. Nested calls are
  /// supported (only the outermost flushes); if [action] throws, the
  /// pending queue is discarded and the exception propagates. Only affects
  /// manual subscriptions — an [Observer] already coalesces rebuilds per
  /// frame on its own.
  ///
  /// Executa [action], agrupando toda escrita em [Observable]/coleção
  /// dentro dele para que cada uma distinta alterada notifique seus
  /// listeners manuais ([listen]/`ever`) exatamente uma vez, após [action]
  /// retornar — as escritas se aplicam imediatamente, só a *notificação* é
  /// adiada. Chamadas aninhadas são suportadas (só a mais externa libera o
  /// flush); se [action] lançar, a fila pendente é descartada e a exceção
  /// se propaga. Afeta apenas subscrições manuais — um [Observer] já
  /// agrupa rebuilds por frame por conta própria.
  ///
  /// ```dart
  /// Observable.batch(() {
  ///   firstName.value = 'Carlos';
  ///   lastName.value = 'Castro';
  /// }); // manual listeners fire exactly once at the end.
  /// ```
  static void batch(void Function() action) => BatchScope.run(action);

  /// The pure-Dart engine this class wraps. See `CoreObservable`'s class
  /// doc: it owns the value, the registry, `equals`, `peek`/`previousValue`,
  /// and dispatches `ObserverInspector` events. This class layers
  /// [ValueListenable] plus the `kDebugMode`-gated colored console logging
  /// (via [ObserverLogger], with `dispatch: false` everywhere below — the
  /// inspector event for each of these already fired from [_core] itself,
  /// so passing `dispatch: false` here only adds the console line, never a
  /// second inspector notification).
  ///
  /// O motor em Dart puro que esta classe envolve. Ver o doc de classe de
  /// `CoreObservable`: ele possui o valor, o registro, o `equals`,
  /// `peek`/`previousValue`, e despacha eventos `ObserverInspector`. Esta
  /// classe adiciona [ValueListenable] mais o logging colorido no console
  /// controlado por `kDebugMode` (via [ObserverLogger], com `dispatch:
  /// false` em todo lugar abaixo — o evento de inspector para cada um
  /// destes já disparou a partir de [_core], então passar `dispatch: false`
  /// aqui só adiciona a linha de console, nunca uma segunda notificação de
  /// inspector).
  final CoreObservable<T> _core;

  /// Stable identity used by Observer Protocol events and snapshots.
  ///
  /// Identidade estável usada nos eventos e snapshots do Observer Protocol.
  ObserverNodeId get objectId => _core.objectId;

  String get _label => _core.label;

  /// Whether [close] has already been called on this observable.
  ///
  /// Se [close] já foi chamado neste observável.
  bool get isClosed => _core.isClosed;

  /// Whether this observable currently has at least one listener attached
  /// (an [Observer] tracking it, or a manual [listen]/[addListener] call).
  ///
  /// Se este observável tem atualmente ao menos um listener anexado (um
  /// [Observer] rastreando-o, ou uma chamada manual a [listen]/
  /// [addListener]).
  bool get hasListeners => _core.hasListeners;

  @override
  T get value => _core.value;

  /// Reads [value] without registering it as a dependency of whatever
  /// [Observer]/`Computed`/`Effect` is currently tracking (if any). Sugar
  /// for `untracked(() => observable.value)`.
  ///
  /// Lê [value] sem registrá-lo como dependência do
  /// [Observer]/`Computed`/`Effect` que estiver rastreando no momento (se
  /// houver algum). Açúcar para `untracked(() => observable.value)`.
  T peek() => _core.peek();

  /// The value this observable held immediately before its most recent
  /// notified change, or `null` if it has never changed since creation.
  /// Only updated by an actual value change (the [value] setter when the
  /// new value differs); [refresh] does not touch it, since the value
  /// itself did not change.
  ///
  /// O valor que este observável tinha imediatamente antes de sua mudança
  /// notificada mais recente, ou `null` se nunca mudou desde a criação. Só
  /// é atualizado por uma mudança de valor de fato (o setter [value] quando
  /// o novo valor difere); [refresh] não o altera, já que o valor em si não
  /// mudou.
  T? get previousValue => _core.previousValue;

  /// Assigns [newValue], notifying listeners only if it differs from the
  /// current value (`!=`). No-ops with a debug warning if the observable
  /// was already [close]d.
  ///
  /// Atribui [newValue], notificando os listeners apenas se ele for
  /// diferente do valor atual (`!=`). Não faz nada (com warning em debug)
  /// se o observável já tiver sido [close]d.
  set value(T newValue) {
    // `_core.value =` below calls straight into `_core.notifyListeners()`
    // (CoreObservable's own), bypassing this class's [notifyListeners]
    // override (and the installer call inside it) entirely — so this needs
    // its own copy here, unconditionally, before any write-triggered
    // cascade can possibly reach a cycle-detection guard downstream.
    ObserverLogger.ensureErrorReporterInstalled();
    if (_core.isClosed) {
      if (kDebugMode) {
        ObserverLogger.warn(
          'Tentativa de alterar $_label já descartado. Ignorado.',
          dispatch: false,
        );
      }
      return;
    }
    if (_core.equals(_core.peek(), newValue)) {
      return;
    }
    // Console-only mirror of the check `_core.value =` is about to perform
    // internally (CoreObservable._checkWriteDuringTracking): the actual
    // strictMode throw, and the WarningEvent dispatch for the non-strict
    // case, both happen inside that call below — this only reproduces the
    // identical kDebugMode-gated console line, without a second dispatch.
    if (kDebugMode &&
        !ObserverConfig.strictMode &&
        DependencyTracker.current != null) {
      ObserverLogger.warn(
        '$_label alterado DURANTE o build de um Observer.',
        suggestion:
            'Isso causa loop de rebuild. Mova a alteração para '
            'fora do build.',
        dispatch: false,
      );
    }
    final T oldValue = _core.peek();
    _core.value = newValue; // may throw ObserverError in strictMode
    if (kDebugMode) {
      ObserverLogger.updated(_label, oldValue, newValue, dispatch: false);
    }
  }

  /// Shorthand for assigning [newValue], mirroring `observable(newValue)`.
  ///
  /// Note: because [call] treats a `null` argument as "no argument" (to
  /// support the no-arg `observable()` read form), it cannot be used to
  /// assign `null` itself to an `Observable<T?>` — `observable(null)` reads
  /// the current value instead of assigning `null`. Use [setValue] or
  /// `value = null` for that case.
  ///
  /// Atalho para atribuir [newValue], equivalente a
  /// `observable(newValue)`.
  ///
  /// Nota: como [call] trata um argumento `null` como "nenhum argumento"
  /// (para suportar a forma de leitura sem argumento `observable()`), ele
  /// não pode ser usado para atribuir `null` a um `Observable<T?>` —
  /// `observable(null)` lê o valor atual em vez de atribuir `null`. Use
  /// [setValue] ou `value = null` nesse caso.
  T call([T? newValue]) {
    if (newValue != null) {
      value = newValue;
    }
    return _core.peek();
  }

  /// Assigns [newValue], equivalent to `value = newValue`. Provided as a
  /// regular method (rather than only the `value =` setter) for call sites
  /// that need a tear-off (e.g. passing it directly as an `onChanged`
  /// callback), and to unambiguously assign `null` to an `Observable<T?>`
  /// — unlike [call], which treats a `null` argument as "no argument".
  ///
  /// Atribui [newValue], equivalente a `value = newValue`. Fornecido como
  /// um método comum (em vez de apenas o setter `value =`) para pontos de
  /// uso que precisam de um tear-off (ex.: passar diretamente como um
  /// callback `onChanged`), e para atribuir `null` a um `Observable<T?>`
  /// sem ambiguidade — diferente de [call], que trata um argumento `null`
  /// como "nenhum argumento".
  void setValue(T newValue) {
    value = newValue;
  }

  /// Forces listener notification without changing [value]. Use this after
  /// mutating a referenced object's internal state in place.
  ///
  /// Subclasses may extend the semantics of [refresh] beyond a simple
  /// notification. For example, [ObservableFuture.refresh] re-runs the
  /// underlying `Future` factory instead of only notifying — callers can
  /// always rely on [refresh] meaning "make listeners aware that something
  /// changed", while subclasses decide what "changed" entails for their type.
  ///
  /// Força a notificação dos listeners sem alterar [value]. Use após
  /// mutar o estado interno de um objeto referenciado, no próprio lugar.
  ///
  /// Subclasses podem estender a semântica de [refresh] além de uma simples
  /// notificação. Por exemplo, [ObservableFuture.refresh] re-executa a
  /// factory de `Future` subjacente em vez de apenas notificar — quem chama
  /// pode sempre contar com [refresh] significando "avisar os listeners que
  /// algo mudou", enquanto subclasses decidem o que "mudou" implica para
  /// seu tipo.
  void refresh() {
    // See the identical call + comment in `set value` below: `_core
    // .refresh()` calls straight into `_core.notifyListeners()`, bypassing
    // this class's own [notifyListeners] override (and its installer call)
    // entirely — so this needs its own copy to stay reliable for a
    // refresh-only usage pattern that never went through a `value =` write.
    ObserverLogger.ensureErrorReporterInstalled();
    _core.refresh();
  }

  /// Subscribes [callback] to future value changes without going through
  /// an [Observer] widget. If [immediate] is `true`, [callback] also fires
  /// once immediately with the current value. If this observable is
  /// already [close]d, returns an already-canceled (inert) subscription
  /// and never registers a listener — [immediate] still fires once, since
  /// reading the last value is harmless.
  ///
  /// Inscreve [callback] para mudanças futuras de valor sem passar por um
  /// widget [Observer]. Se [immediate] for `true`, [callback] também
  /// dispara uma vez imediatamente com o valor atual. Se este observável já
  /// tiver sido [close]d, retorna uma subscrição já cancelada (inerte) e
  /// nunca registra um listener — [immediate] ainda dispara uma vez, já que
  /// ler o último valor é inofensivo.
  /// [when], if provided, is checked before every invocation (including
  /// the [immediate] one): [callback] only runs while `when(value)` is
  /// `true`. This is a plain `if` guard around the call — no extra
  /// tracking, no `Stream`/`where` involved — so it costs nothing beyond
  /// the predicate call itself.
  ///
  /// [when], se fornecido, é checado antes de toda invocação (incluindo a
  /// [immediate]): [callback] só roda enquanto `when(value)` for `true`.
  /// Isso é uma simples guarda `if` em torno da chamada — nenhum
  /// rastreamento extra, nenhum `Stream`/`where` envolvido — então não
  /// custa nada além da própria chamada do predicado.
  ObservableSubscription listen(
    ObserverCallback<T> callback, {
    bool immediate = false,
    bool Function(T value)? when,
  }) {
    final ObservableSubscription subscription = _core.listen(
      callback,
      immediate: immediate,
      when: when,
    );
    if (!_core.isClosed) {
      _warnIfPossibleLeak();
    }
    return subscription;
  }

  void _warnIfPossibleLeak() {
    // dispatch: false — CoreObservable.listen/addListener already
    // dispatched their own (dispatch-only) possible-leak WarningEvent
    // internally; this only adds the console line.
    if (kDebugMode &&
        _core.registry.length >= ObserverConfig.listenerLeakThreshold) {
      ObserverLogger.warn(
        '$_label tem ${_core.registry.length}+ listeners. Possível '
        'vazamento.',
        suggestion: 'Observers sendo criados sem descarte?',
        dispatch: false,
      );
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _core.addListener(listener);
    _warnIfPossibleLeak();
  }

  @override
  void removeListener(VoidCallback listener) {
    _core.removeListener(listener);
  }

  /// Notifies every current listener. Exposed for subclasses (e.g.
  /// collections) that mutate internal state through means other than the
  /// [value] setter.
  ///
  /// Notifica todos os listeners atuais. Exposto para subclasses (ex.:
  /// coleções) que mutam o estado interno por outros meios além do setter
  /// [value].
  @protected
  void notifyListeners() {
    ObserverLogger.ensureErrorReporterInstalled();
    _core.notifyListeners();
  }

  /// Disposes this observable: removes all listeners and marks it
  /// [isClosed]. Subsequent writes are ignored with a debug warning.
  ///
  /// Descarta este observável: remove todos os listeners e o marca como
  /// [isClosed]. Escritas subsequentes são ignoradas com warning em debug.
  void close() {
    if (_core.isClosed) {
      return;
    }
    final int removed = _core.registry.length;
    _core.close();
    if (kDebugMode) {
      ObserverLogger.disposed(_label, removed, dispatch: false);
    }
  }
}
