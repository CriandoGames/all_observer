import 'batch_scope.dart';
import 'dependency_tracker.dart';
import 'listener_registry.dart';
import 'observer_inspector.dart';
import 'reactive_scope.dart';
import 'typedefs.dart';
import '../logging/observer_config.dart';
import '../observable/observable_subscription.dart';

/// Pure-Dart derived-value engine: the same lazy/memoized, glitch-free
/// tracking behind `Computed`, without any dependency on `package:flutter`
/// — no `ValueListenable`, no `kDebugMode`-gated console logging. Usable
/// from a CLI/server context via `package:all_observer/core.dart`.
///
/// `Computed<T>` (in the main `all_observer.dart` barrel) wraps a
/// [CoreComputed] and layers `ValueListenable<T>` plus the colored debug
/// -console dispose logging on top for Flutter apps.
///
/// See `Computed`'s class doc for the full behavior contract (lazy first
/// compute, memoization, change-filtering, dynamic dependencies, diamond
/// -glitch handling via `BatchScope`) — identical here, since this class
/// *is* that engine.
///
/// Contêiner de valor derivado em Dart puro: o mesmo rastreamento
/// preguiçoso/memoizado e livre de glitch por trás de `Computed`, sem
/// nenhuma dependência de `package:flutter` — sem `ValueListenable`, sem
/// logging de console controlado por `kDebugMode`. Utilizável em um
/// contexto de CLI/servidor via `package:all_observer/core.dart`.
class CoreComputed<T> {
  /// Creates a [CoreComputed] that derives its value by running [compute].
  /// See `Computed`'s constructor for the meaning of [name] and [equals] —
  /// identical here. [compute] does not run until [value] is first read.
  ///
  /// If a `ReactiveScope` is currently active (`ReactiveScope.current`),
  /// [close] is registered in it, so disposing the scope closes this
  /// instance. Registration lives here — the core engine — rather than in
  /// the Flutter `Computed` wrapper, so both layers (and `select()`, which
  /// builds on `Computed`) participate through a single, non-duplicated
  /// point. Created outside any scope, behavior is unchanged: nothing is
  /// registered anywhere.
  ///
  /// Cria um [CoreComputed] que deriva seu valor executando [compute]. Ver
  /// o construtor de `Computed` para o significado de [name] e [equals] —
  /// idêntico aqui. [compute] não roda até que [value] seja lido pela
  /// primeira vez.
  ///
  /// Se um `ReactiveScope` estiver ativo (`ReactiveScope.current`), [close]
  /// é registrado nele, então descartar o escopo fecha esta instância. O
  /// registro vive aqui — no motor do core — em vez de no wrapper Flutter
  /// `Computed`, para que ambas as camadas (e o `select()`, que constrói
  /// sobre `Computed`) participem por um único ponto, sem duplicação.
  /// Criado fora de qualquer escopo, o comportamento é o de antes: nada é
  /// registrado em lugar nenhum.
  CoreComputed(this._compute, {String? name, bool Function(T a, T b)? equals})
    : _name = name,
      _equals = equals ?? _defaultEquals {
    ReactiveScope.current?.add(close);
  }

  static bool _defaultEquals<T>(T a, T b) => a == b;

  final T Function() _compute;
  final String? _name;
  final bool Function(T a, T b) _equals;

  /// The listener registry backing this [CoreComputed]. Exposed mainly for
  /// the Flutter `Computed` wrapper (e.g. to count listeners on dispose).
  ///
  /// O registro de listeners por trás deste [CoreComputed]. Exposto
  /// principalmente para o wrapper Flutter `Computed` (ex.: para contar
  /// listeners no descarte).
  final ListenerRegistry registry = ListenerRegistry();

  bool _hasValue = false;
  late T _value;
  List<Disposer> _dependencyDisposers = <Disposer>[];
  bool _isClosed = false;
  bool _dirty = false;

  /// Debug label used in inspector events: [name], if given, otherwise a
  /// short hash-based fallback.
  ///
  /// Rótulo de debug usado em eventos de inspector: [name], se fornecido,
  /// senão um fallback curto baseado no hash.
  String get label => 'Computed(${_name ?? '#$hashCode'})';

  /// Whether [close] has already been called.
  ///
  /// Se [close] já foi chamado.
  bool get isClosed => _isClosed;

  /// Reads the current value, computing it lazily on first read and
  /// registering it as a dependency of whatever tracking context is
  /// currently active. See `Computed.value` for the full diamond-glitch
  /// note — identical here.
  ///
  /// Lê o valor atual, calculando-o preguiçosamente na primeira leitura e
  /// registrando-o como dependência de qualquer contexto de rastreamento
  /// ativo no momento. Ver `Computed.value` para a nota completa sobre o
  /// glitch do diamante — idêntica aqui.
  T get value {
    DependencyTracker.reportRead(registry, label: label);
    _ensureLive();
    _flushIfDirty();
    return _value;
  }

  void _ensureLive() {
    if (!_hasValue) {
      _recompute();
    }
  }

  void _recompute() {
    _clearDependencies();
    final TrackingContext context = TrackingContext(
      _onDependencyChanged,
      ownerLabel: label,
    );
    try {
      final T newValue = DependencyTracker.track(context, _compute);
      final bool changed = !_hasValue || !_equals(_value, newValue);
      _hasValue = true;
      _value = newValue;
      if (changed) {
        registry.notifyOrQueue();
      }
    } finally {
      _dependencyDisposers = context.disposers;
    }
  }

  void _onDependencyChanged() {
    if (_isClosed) {
      return;
    }
    if (BatchScope.isActive) {
      if (!_dirty) {
        _dirty = true;
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

  /// Adds a raw listener. Exposed mainly for the Flutter `ValueListenable`
  /// adapter.
  ///
  /// Adiciona um listener bruto. Exposto principalmente para o adapter
  /// Flutter de `ValueListenable`.
  void addListener(ObserverVoidCallback listener) {
    _ensureLive();
    registry.add(listener);
  }

  /// Removes a listener added via [addListener].
  ///
  /// Remove um listener adicionado via [addListener].
  void removeListener(ObserverVoidCallback listener) =>
      registry.remove(listener);

  /// Subscribes [callback] to future recomputed values, mirroring
  /// `Observable.listen`.
  ///
  /// Inscreve [callback] para valores recalculados futuros, espelhando
  /// `Observable.listen`.
  ObservableSubscription listen(void Function(T value) callback) {
    _ensureLive();
    void listener() => callback(value);
    final Disposer dispose = registry.add(listener);
    return ObservableSubscription.fromDisposer(dispose);
  }

  /// Disposes this [CoreComputed]: unsubscribes from all current
  /// dependencies and clears its own listeners. Safe to call more than
  /// once.
  ///
  /// Descarta este [CoreComputed]: cancela a inscrição em todas as
  /// dependências atuais e limpa seus próprios listeners. Seguro chamar
  /// mais de uma vez.
  void close() {
    if (_isClosed) {
      return;
    }
    _clearDependencies();
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
