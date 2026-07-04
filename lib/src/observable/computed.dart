import 'package:flutter/foundation.dart';

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
  /// Cria um [Computed] que deriva seu valor executando [compute]. Um
  /// [name] opcional é usado nos logs de debug. [compute] não roda até que
  /// [value] seja lido pela primeira vez.
  Computed(this._compute, {String? name}) : _name = name;

  final T Function() _compute;
  final String? _name;
  final ListenerRegistry _registry = ListenerRegistry();

  bool _hasValue = false;
  late T _value;
  List<Disposer> _dependencyDisposers = <Disposer>[];
  bool _isClosed = false;

  String get _label => 'Computed(${_name ?? '#$hashCode'})';

  /// Whether [close] has already been called.
  ///
  /// Se [close] já foi chamado.
  bool get isClosed => _isClosed;

  @override
  T get value {
    DependencyTracker.reportRead(_registry, label: _label);
    if (!_hasValue) {
      _recompute();
    }
    return _value;
  }

  void _recompute() {
    _clearDependencies();
    final TrackingContext context = TrackingContext(_onDependencyChanged);
    final T newValue = DependencyTracker.track(context, _compute);
    _dependencyDisposers = context.disposers;
    // Compare against the still-valid previous value/flag *before*
    // overwriting either. `_hasValue` is only ever cleared by nothing but
    // the constructor's initial state here — dependency-triggered
    // recomputes never reset it — so this is a plain "did the derived
    // value change" check, not "is this the very first compute".
    final bool changed = !_hasValue || _value != newValue;
    _hasValue = true;
    _value = newValue;
    if (changed) {
      _registry.notifyOrQueue();
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
  // Nota sobre laziness: apenas o *primeiro* cálculo é preguiçoso (adiado
  // até a primeira leitura de `value`). Uma vez que uma dependência já foi
  // lida ao menos uma vez, mudanças subsequentes de dependência recalculam
  // imediatamente aqui, pois este Computed precisa saber o novo valor de
  // imediato para decidir se ele realmente mudou e, portanto, se deve
  // notificar seus próprios listeners.
  void _onDependencyChanged() {
    if (_isClosed) {
      return;
    }
    _recompute();
  }

  void _clearDependencies() {
    for (final Disposer dispose in _dependencyDisposers) {
      dispose();
    }
    _dependencyDisposers = <Disposer>[];
  }

  @override
  void addListener(VoidCallback listener) => _registry.add(listener);

  @override
  void removeListener(VoidCallback listener) => _registry.remove(listener);

  /// Subscribes [callback] to future recomputed values, mirroring
  /// `Observable.listen`.
  ///
  /// Inscreve [callback] para valores recalculados futuros, espelhando
  /// `Observable.listen`.
  ObservableSubscription listen(void Function(T value) callback) {
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
