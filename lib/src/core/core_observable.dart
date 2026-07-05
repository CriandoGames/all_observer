import 'batch_scope.dart';
import 'dependency_tracker.dart';
import 'listener_registry.dart';
import 'observer_inspector.dart';
import 'typedefs.dart';
import 'untracked.dart';
import '../errors/observer_error.dart';
import '../logging/observer_config.dart';
import '../observable/observable_subscription.dart';

/// Pure-Dart reactive value holder: the same tracking/notification engine
/// behind `Observable`, without any dependency on `package:flutter` — no
/// `ValueListenable`, no `kDebugMode`-gated console logging. Usable from a
/// CLI/server context via `package:all_observer/core.dart`.
///
/// `Observable<T>` (in the main `all_observer.dart` barrel) wraps a
/// [CoreObservable] and layers `ValueListenable<T>` plus the colored debug
/// -console logging on top for Flutter apps — this class is the shared
/// engine underneath both, so behavior (lazy tracking, `equals`,
/// glitch-free batching, `peek`/`previousValue`, strict-mode warnings)
/// stays identical between the two.
///
/// Observability is still available here: every create/update/dispose/
/// warning is dispatched to `ObserverConfig.inspectors` (itself pure Dart),
/// so a `RecordingInspector` works the same whether you're in a Flutter app
/// or a plain Dart script.
///
/// Contêiner reativo de valor em Dart puro: o mesmo motor de rastreamento/
/// notificação por trás de `Observable`, sem nenhuma dependência de
/// `package:flutter` — sem `ValueListenable`, sem logging de console
/// controlado por `kDebugMode`. Utilizável em um contexto de CLI/servidor
/// via `package:all_observer/core.dart`.
class CoreObservable<T> {
  /// Creates a [CoreObservable] holding [initialValue]. See `Observable`'s
  /// constructor for the meaning of [name] and [equals] — identical here.
  ///
  /// Cria um [CoreObservable] contendo [initialValue]. Ver o construtor de
  /// `Observable` para o significado de [name] e [equals] — idêntico aqui.
  CoreObservable(
    T initialValue, {
    String? name,
    bool Function(T a, T b)? equals,
  }) : _value = initialValue,
       _name = name,
       _equals = equals ?? _defaultEquals {
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onCreate(
        ObservableCreateEvent(
          label,
          _value,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
  }

  static bool _defaultEquals<T>(T a, T b) => a == b;

  final ListenerRegistry registry = ListenerRegistry();
  final String? _name;
  final bool Function(T a, T b) _equals;
  T _value;
  T? _previousValue;
  bool _isClosed = false;

  /// Debug label used in inspector events and warnings: [name], if given,
  /// otherwise a short hash-based fallback.
  ///
  /// Rótulo de debug usado em eventos de inspector e warnings: [name], se
  /// fornecido, senão um fallback curto baseado no hash.
  String get label => '$runtimeType(${_name ?? '#$hashCode'})';

  /// Whether [close] has already been called on this observable.
  ///
  /// Se [close] já foi chamado neste observável.
  bool get isClosed => _isClosed;

  /// Whether this observable currently has at least one listener attached.
  ///
  /// Se este observável tem atualmente ao menos um listener anexado.
  bool get hasListeners => registry.hasListeners;

  /// Reads the current value, registering it as a dependency of whatever
  /// tracking context (`Observer`/`Computed`/`Effect`) is currently active.
  ///
  /// Lê o valor atual, registrando-o como dependência de qualquer contexto
  /// de rastreamento (`Observer`/`Computed`/`Effect`) ativo no momento.
  T get value {
    DependencyTracker.reportRead(registry, label: label);
    return _value;
  }

  /// Reads [value] without registering it as a dependency. Sugar for
  /// `untracked(() => observable.value)`.
  ///
  /// Lê [value] sem registrá-lo como dependência. Açúcar para
  /// `untracked(() => observable.value)`.
  T peek() => untracked(() => value);

  /// The value held immediately before the most recent notified change, or
  /// `null` if it has never changed since creation. See `Observable
  /// .previousValue` for full semantics — identical here.
  ///
  /// O valor mantido imediatamente antes da mudança notificada mais
  /// recente, ou `null` se nunca mudou desde a criação. Ver `Observable
  /// .previousValue` para a semântica completa — idêntica aqui.
  T? get previousValue => _previousValue;

  /// Assigns [newValue], notifying listeners only if it differs from the
  /// current value. No-ops (with a dispatched warning) if already closed.
  ///
  /// Atribui [newValue], notificando os listeners apenas se ele diferir do
  /// valor atual. Não faz nada (com um warning despachado) se já fechado.
  set value(T newValue) {
    if (_isClosed) {
      _warn('Tentativa de alterar $label já descartado. Ignorado.');
      return;
    }
    if (_equals(_value, newValue)) {
      return;
    }
    _checkWriteDuringTracking();
    final T oldValue = _value;
    _previousValue = oldValue;
    _value = newValue;
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onUpdate(
        ObservableUpdateEvent(
          label,
          oldValue,
          newValue,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
    notifyListeners();
  }

  /// Assigns [newValue], equivalent to `value = newValue`. Provided as a
  /// plain method for call sites that need a tear-off.
  ///
  /// Atribui [newValue], equivalente a `value = newValue`. Fornecido como
  /// um método comum para pontos de uso que precisam de um tear-off.
  void setValue(T newValue) {
    value = newValue;
  }

  /// Forces listener notification without changing [value].
  ///
  /// Força a notificação dos listeners sem alterar [value].
  void refresh() {
    if (_isClosed) {
      return;
    }
    notifyListeners();
  }

  /// Subscribes [callback] to future value changes. See `Observable.listen`
  /// for the meaning of [immediate] and [when] — identical here.
  ///
  /// Inscreve [callback] para mudanças futuras de valor. Ver
  /// `Observable.listen` para o significado de [immediate] e [when] —
  /// idêntico aqui.
  ObservableSubscription listen(
    ObserverCallback<T> callback, {
    bool immediate = false,
    bool Function(T value)? when,
  }) {
    if (_isClosed) {
      if (immediate && (when == null || when(_value))) {
        callback(_value);
      }
      final ObservableSubscription inert = ObservableSubscription.fromDisposer(
        () {},
      );
      inert.cancel();
      return inert;
    }
    void listener() {
      if (when == null || when(_value)) {
        callback(_value);
      }
    }

    final Disposer dispose = registry.add(listener);
    if (immediate && (when == null || when(_value))) {
      callback(_value);
    }
    _warnIfPossibleLeak();
    return ObservableSubscription.fromDisposer(dispose);
  }

  void _warnIfPossibleLeak() {
    if (registry.length >= ObserverConfig.listenerLeakThreshold) {
      _warn(
        '$label tem ${registry.length}+ listeners. Possível vazamento.',
        suggestion: 'Observers sendo criados sem descarte?',
      );
    }
  }

  /// Adds a raw listener (no `when`/`immediate` support — see [listen] for
  /// that). Exposed mainly for the Flutter `ValueListenable` adapter.
  ///
  /// Adiciona um listener bruto (sem suporte a `when`/`immediate` — ver
  /// [listen] para isso). Exposto principalmente para o adapter Flutter de
  /// `ValueListenable`.
  void addListener(ObserverVoidCallback listener) {
    registry.add(listener);
    _warnIfPossibleLeak();
  }

  /// Removes a listener added via [addListener].
  ///
  /// Remove um listener adicionado via [addListener].
  void removeListener(ObserverVoidCallback listener) {
    registry.remove(listener);
  }

  void _checkWriteDuringTracking() {
    if (DependencyTracker.current == null) {
      return;
    }
    final String message = '$label alterado DURANTE o build de um Observer.';
    if (ObserverConfig.strictMode) {
      throw ObserverError(message);
    }
    _warn(
      message,
      suggestion: 'Isso causa loop de rebuild. Mova a alteração para '
          'fora do build.',
    );
  }

  void _warn(String message, {String? suggestion}) {
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onWarning(
        WarningEvent(
          message,
          suggestion: suggestion,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
  }

  /// Notifies every current listener. Exposed for subclasses/wrappers (e.g.
  /// collections, or the Flutter `Observable` adapter) that mutate state
  /// through means other than the [value] setter.
  ///
  /// Notifica todos os listeners atuais. Exposto para subclasses/wrappers
  /// (ex.: coleções, ou o adapter Flutter de `Observable`) que mutam o
  /// estado por outros meios além do setter [value].
  void notifyListeners() {
    registry.notifyOrQueue();
  }

  /// Disposes this observable: removes all listeners and marks it
  /// [isClosed].
  ///
  /// Descarta este observável: remove todos os listeners e o marca como
  /// [isClosed].
  void close() {
    if (_isClosed) {
      return;
    }
    final int removed = registry.length;
    registry.clear();
    _isClosed = true;
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onDispose(
        ObservableDisposeEvent(
          label,
          removed,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
  }
}
