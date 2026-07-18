import 'batch_scope.dart';
import 'dependency_tracker.dart';
import 'engine_bridge.dart';
import 'listener_registry.dart';
import 'observer_inspector.dart';
import 'reactive_scope.dart';
import 'typedefs.dart';
import 'untracked.dart';
import '../engine/reactive_engine.dart';
import '../errors/observer_cycle_error.dart';
import '../logging/observer_config.dart';
import '../observable/observable_subscription.dart';
import '../protocol/observer_protocol.dart';
import '../protocol/observer_protocol_event.dart';

/// Pure-Dart derived-value engine: the same lazy/memoized, glitch-free
/// tracking behind `Computed`, without any dependency on `package:flutter`
/// — no `ValueListenable`, no `kDebugMode`-gated console logging. Usable
/// from a CLI/server context via `package:all_observer/core.dart`.
///
/// `Computed<T>` (in the main `all_observer.dart` barrel) wraps a
/// [CoreComputed] and layers `ValueListenable<T>` plus the colored debug
/// -console dispose logging on top for Flutter apps.
///
/// Since engine v2 (Fase 2), dependency tracking and invalidation run on
/// the public `ReactiveEngine` graph (`package:all_observer/engine.dart`)
/// instead of per-recompute registry subscriptions:
///
/// - dependencies are intrusive engine links, reused in place across
///   recomputes (zero allocation when the read set doesn't change);
/// - invalidation is push-pull: writes only mark this computed stale
///   through the engine graph, and an internal engine watcher (created on
///   first evaluation, kept until [close]) pulls the fresh value in phase 2
///   of the same two-phase `BatchScope` flush as always — so the observable
///   timing (`addListener`/`listen`/`Observer`, eager settling per flush)
///   is unchanged;
/// - a read that lands between marking and settling resolves lazily on the
///   spot (`checkDirty`), which is also what heals ordering in deep
///   cascades.
///
/// The `equals` filter, lazy first compute, memoization, inspector events
/// and `ObserverCycleError` guards all behave as documented on `Computed`.
///
/// Contêiner de valor derivado em Dart puro: o mesmo rastreamento
/// preguiçoso/memoizado e livre de glitch por trás de `Computed`, sem
/// nenhuma dependência de `package:flutter`. Desde o motor v2 (Fase 2), o
/// rastreamento de dependências e a invalidação rodam no grafo público
/// `ReactiveEngine` (`package:all_observer/engine.dart`): dependências são
/// links intrusivos reusados entre recomputações, e a invalidação é
/// push-pull: escritas só marcam obsolescência pelo grafo do motor, e um
/// watcher interno (criado na primeira avaliação, mantido até o [close])
/// puxa o valor fresco na fase 2 do mesmo flush em duas fases do
/// `BatchScope` de sempre — preservando o timing observável de
/// `addListener`/`listen`/`Observer`. Uma leitura entre a marcação e a
/// estabilização se resolve preguiçosamente na hora (`checkDirty`).
///
/// Observer Protocol reuses the exact recomputation boundary to pair runs and
/// publish dependency deltas; scheduling and equality semantics do not change.
///
/// O Observer Protocol reutiliza a fronteira exata de recomputação para parear
/// execuções e publicar deltas; scheduler e igualdade não mudam.
class CoreComputed<T> {
  /// Creates a [CoreComputed] that derives its value by running [compute].
  /// See `Computed`'s constructor for the meaning of [name] and [equals] —
  /// identical here. [compute] does not run until [value] is first read.
  ///
  /// If a `ReactiveScope` is currently active (`ReactiveScope.current`),
  /// [close] is registered in it, so disposing the scope closes this
  /// instance — identical to the pre-engine behavior.
  ///
  /// Cria um [CoreComputed] que deriva seu valor executando [compute]. Ver
  /// o construtor de `Computed` para o significado de [name] e [equals] —
  /// idêntico aqui. [compute] não roda até que [value] seja lido pela
  /// primeira vez.
  ///
  /// Se um `ReactiveScope` estiver ativo (`ReactiveScope.current`), [close]
  /// é registrado nele — idêntico ao comportamento pré-motor.
  CoreComputed(this._compute, {String? name, bool Function(T a, T b)? equals})
    : _name = name,
      _equals = equals ?? _defaultEquals {
    _node = ComputedEngineNode(
      onEngineUpdate: _didUpdate,
      onEngineUnwatched: _onEngineUnwatched,
    );
    registry.engineNode = _node;
    registry.protocolNodeId = objectId;
    _protocolTracker = ObserverProtocol.tracker(
      trackerId: objectId,
      kind: ObserverNodeKind.computed,
    );
    ObserverProtocol.nodeCreated(
      objectId: objectId,
      kind: ObserverNodeKind.computed,
      debugLabel: label,
      debugType: runtimeType.toString(),
    );
    ReactiveScope.current?.add(
      close,
      resourceId: objectId,
      resourceKind: ObserverNodeKind.computed,
    );
  }

  static bool _defaultEquals<T>(T a, T b) => a == b;

  static void _noopInvalidate() {}

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

  /// Stable identity used by Observer Protocol events and snapshots.
  ///
  /// Identidade estável usada nos eventos e snapshots do Observer Protocol.
  final ObserverNodeId objectId = ObserverProtocol.allocateNodeId();
  late final ObserverProtocolTracker _protocolTracker;

  late final ComputedEngineNode _node;
  WatcherNode? _watcher;
  bool _hasValue = false;
  late T _value;
  bool _isClosed = false;

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
  /// currently active — an `Observer`/`effect` (via this computed's
  /// [registry]) or another recomputing `CoreComputed` (via the engine
  /// graph). See `Computed.value` for the full diamond-glitch note —
  /// identical here.
  ///
  /// Lê o valor atual, calculando-o preguiçosamente na primeira leitura e
  /// registrando-o como dependência de qualquer contexto de rastreamento
  /// ativo no momento — um `Observer`/`effect` (via o [registry] deste
  /// computed) ou outro `CoreComputed` recomputando (via o grafo do
  /// motor). Ver `Computed.value` para a nota completa sobre o glitch do
  /// diamante — idêntica aqui.
  T get value {
    DependencyTracker.reportRead(registry, label: label);
    _pull();
    return _value;
  }

  /// Brings [_value] up to date: computes on first read, confirms staleness
  /// lazily (`checkDirty`) when only marked `pending`, and recomputes when
  /// `dirty`. Detects self-dependency cycles.
  ///
  /// Atualiza [_value]: computa na primeira leitura, confirma obsolescência
  /// preguiçosamente (`checkDirty`) quando só marcado `pending`, e
  /// recomputa quando `dirty`. Detecta ciclos de autodependência.
  void _pull() {
    if (_isClosed) {
      if (!_hasValue) {
        // First-ever read happening after close: compute once, untracked,
        // so no dependency is ever registered for a dead computed.
        // Primeira leitura acontecendo após o close: computa uma vez, sem
        // rastreamento, para nunca registrar dependência de um computed
        // morto.
        _value = untracked(_compute);
        _hasValue = true;
      }
      return;
    }
    final ReactiveFlags flags = _node.flags;
    if (flags.hasAny(ReactiveFlags.recursedCheck)) {
      throw ObserverCycleError(
        'all_observer: $label depende de si mesmo — seu compute() leu o '
        'próprio value (direta ou indiretamente) durante a recomputação. '
        'Quebre o ciclo lendo o valor anterior fora do compute. / '
        '$label depends on itself: its compute() read its own value '
        '(directly or indirectly) while recomputing.',
      );
    }
    if (flags.hasAny(ReactiveFlags.dirty) ||
        (flags.hasAny(ReactiveFlags.pending) && _confirmStale())) {
      if (_didUpdate()) {
        final ReactiveLink? subs = _node.subs;
        if (subs != null) {
          ObserverEngine.instance.shallowPropagate(subs);
        }
      }
    } else if (flags == ReactiveFlags.none) {
      _firstEval();
    }
  }

  /// Pull-check: confirms whether `pending` really means stale, clearing
  /// the flag when the change was cut upstream (an `equals` firewall).
  ///
  /// Checagem pull: confirma se `pending` significa mesmo obsoleto,
  /// limpando a flag quando a mudança foi cortada acima (um firewall de
  /// `equals`).
  bool _confirmStale() {
    final ReactiveLink? deps = _node.deps;
    if (deps != null && ObserverEngine.instance.checkDirty(deps, _node)) {
      return true;
    }
    _node.flags = _node.flags & ~ReactiveFlags.pending;
    return false;
  }

  /// First evaluation: runs [_compute] with engine tracking active and a
  /// non-subscribing [TrackingContext] (for outer-context isolation and
  /// `onTrack` events). Does not notify anyone — nothing "changed".
  ///
  /// Primeira avaliação: executa [_compute] com o rastreamento do motor
  /// ativo e um [TrackingContext] não-inscritor (para isolamento do
  /// contexto externo e eventos `onTrack`). Não notifica ninguém — nada
  /// "mudou".
  void _firstEval() {
    final ObserverEngine engine = ObserverEngine.instance;
    _node.flags = ReactiveFlags.mutableChecking;
    final ReactiveNode? prevSub = engine.activeSub;
    engine.activeSub = _node;
    final TrackingContext context = TrackingContext(
      _noopInvalidate,
      ownerLabel: label,
      subscribes: false,
      protocolTracker: _protocolTracker,
    );
    var completed = false;
    try {
      _value = DependencyTracker.track(context, _compute);
      _hasValue = true;
      ObserverProtocol.initializeNodeValue(objectId, _value);
      completed = true;
    } finally {
      engine.activeSub = prevSub;
      _node.flags = completed
          ? ReactiveFlags.mutable
          : ReactiveFlags.mutableDirty;
      // Once live, always watched (until [close]): this keeps the package's
      // long-standing contract that a live computed settles eagerly on
      // every batch flush — listeners or not — including retrying after a
      // compute that threw.
      // Uma vez vivo, sempre observado (até o [close]): isso mantém o
      // contrato de longa data do pacote de que um computed vivo se
      // estabiliza ansiosamente a cada flush de batch — com ou sem
      // listeners — inclusive tentando de novo após um compute que lançou.
      _startWatcher();
    }
  }

  /// Recomputes, re-tracking dependencies in place (link reuse + purge of
  /// stale edges), applies the `equals` filter, and — when the value really
  /// changed — notifies this computed's own listeners through the same
  /// two-phase `BatchScope` flush as always. Returns whether the value
  /// changed (the engine's propagation-cut signal).
  ///
  /// Recomputa, re-rastreando dependências no lugar (reuso de links + purge
  /// de arestas obsoletas), aplica o filtro `equals`, e — quando o valor
  /// realmente mudou — notifica os listeners deste computed pelo mesmo
  /// flush em duas fases do `BatchScope` de sempre. Retorna se o valor
  /// mudou (o sinal de corte de propagação do motor).
  bool _didUpdate() {
    final ObserverEngine engine = ObserverEngine.instance;
    _node.depsTail = null;
    _node.flags = ReactiveFlags.mutableChecking;
    final ReactiveNode? prevSub = engine.activeSub;
    engine.activeSub = _node;
    final TrackingContext context = TrackingContext(
      _noopInvalidate,
      ownerLabel: label,
      subscribes: false,
      protocolTracker: _protocolTracker,
    );
    bool changed = false;
    var completed = false;
    final Object? oldValue = _hasValue ? _value : null;
    try {
      ++engine.cycle;
      final T newValue = DependencyTracker.track(context, _compute);
      changed = !_hasValue || !_equals(_value, newValue);
      _hasValue = true;
      _value = newValue;
      completed = true;
    } finally {
      engine.activeSub = prevSub;
      _node.flags = completed
          ? ReactiveFlags.mutable
          : ReactiveFlags.mutableDirty;
      purgeDeps(_node);
    }
    if (changed) {
      ObserverProtocol.nodeUpdated(
        objectId: objectId,
        kind: ObserverNodeKind.computed,
        oldValue: oldValue,
        newValue: _value,
      );
      registry.notifyOrQueue();
    }
    return changed;
  }

  /// Engine `unwatched` hook: nobody (listener or downstream computed)
  /// watches this computed anymore. Deliberately keeps the dependency links
  /// (matching the package's pre-engine behavior, where a computed stayed
  /// subscribed until [close]): `Observer`/`effect` re-tracking disposes
  /// and re-adds registry listeners on every run, so releasing dependencies
  /// here would force a full recompute on each of those "blinks". The
  /// laziness win is preserved regardless — with no watcher attached,
  /// writes only mark this computed stale and the next read settles it.
  /// [close] is what actually releases the links.
  ///
  /// Gancho `unwatched` do motor: ninguém (listener ou computed abaixo)
  /// observa mais este computed. Deliberadamente mantém os links de
  /// dependência (igual ao comportamento pré-motor, em que um computed
  /// ficava inscrito até o [close]): o re-rastreamento de
  /// `Observer`/`effect` descarta e recria listeners de registry a cada
  /// execução, então liberar dependências aqui forçaria uma recomputação
  /// completa a cada uma dessas "piscadas". O ganho de laziness fica
  /// preservado mesmo assim — sem watcher anexado, escritas só marcam este
  /// computed como obsoleto e a próxima leitura resolve. É o [close] que
  /// de fato libera os links.
  void _onEngineUnwatched() {
    // Intentionally empty — see doc above. / Intencionalmente vazio — ver
    // doc acima.
  }

  void _startWatcher() {
    if (_watcher != null) {
      return;
    }
    final ObserverEngine engine = ObserverEngine.instance;
    final WatcherNode watcher = WatcherNode(onInvalidate: _scheduleWatcherPull);
    _watcher = watcher;
    engine.link(_node, watcher, engine.cycle);
  }

  void _stopWatcher() {
    final WatcherNode? watcher = _watcher;
    if (watcher == null) {
      return;
    }
    _watcher = null;
    watcher.flags = ReactiveFlags.none;
    disposeAllDepsInReverse(watcher);
  }

  /// Scheduled by the engine when a dependency may have changed: defers a
  /// pull to phase 2 of the current `BatchScope` flush (or opens a
  /// micro-batch when none is active), exactly where deferred recomputes
  /// always ran.
  ///
  /// Agendado pelo motor quando uma dependência pode ter mudado: adia um
  /// pull para a fase 2 do flush atual do `BatchScope` (ou abre um
  /// micro-batch quando nenhum está ativo), exatamente onde os recomputes
  /// adiados sempre rodaram.
  void _scheduleWatcherPull() {
    if (BatchScope.isActive) {
      BatchScope.queueDirtyFlush(_watcherPull);
    } else {
      BatchScope.run(() => BatchScope.queueDirtyFlush(_watcherPull));
    }
  }

  void _watcherPull() {
    final WatcherNode? watcher = _watcher;
    if (watcher == null || _isClosed) {
      return;
    }
    // Restore `watching` (stripped at notify time so repeated writes in the
    // same wave don't re-schedule) and pull the fresh value; [_didUpdate]
    // notifies the registry if it actually changed.
    // Restaura `watching` (removido na notificação para escritas repetidas
    // na mesma onda não reagendarem) e puxa o valor fresco; [_didUpdate]
    // notifica o registry se realmente mudou.
    watcher.flags = ReactiveFlags.watching;
    _pull();
  }

  /// Adds a raw listener. Exposed mainly for the Flutter `ValueListenable`
  /// adapter.
  ///
  /// Adiciona um listener bruto. Exposto principalmente para o adapter
  /// Flutter de `ValueListenable`.
  void addListener(ObserverVoidCallback listener) {
    _pull();
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
    _pull();
    void listener() => callback(value);
    final Disposer dispose = registry.add(listener);
    return ObservableSubscription.fromDisposer(dispose);
  }

  /// Disposes this [CoreComputed]: releases every engine dependency, stops
  /// the internal watcher and clears its own listeners. Safe to call more
  /// than once.
  ///
  /// Descarta este [CoreComputed]: libera toda dependência no motor, para o
  /// watcher interno e limpa seus próprios listeners. Seguro chamar mais de
  /// uma vez.
  void close() {
    if (_isClosed) {
      return;
    }
    _stopWatcher();
    disposeAllDepsInReverse(_node);
    _node.flags = ReactiveFlags.none;
    final int removed = registry.length;
    registry.clear();
    _isClosed = true;
    ObserverProtocol.disposeTracker(_protocolTracker);
    ObserverProtocol.nodeDisposed(
      objectId: objectId,
      kind: ObserverNodeKind.computed,
      listenerCount: removed,
    );
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
