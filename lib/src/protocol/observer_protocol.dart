import 'internal/node_protocol_runtime.dart';
import 'internal/protocol_runtime_state.dart';
import 'internal/scope_protocol_runtime.dart';
import 'internal/tracker_protocol_runtime.dart';
import 'observer_protocol_config.dart';
import 'observer_protocol_event.dart';
import 'observer_protocol_tracking.dart';

export 'observer_protocol_config.dart';
export 'observer_protocol_tracking.dart';

/// Global Observer Protocol facade and current-state registry.
///
/// Fachada global do Observer Protocol e registry do estado atual.
abstract final class ObserverProtocol {
  static final ProtocolRuntimeState _state = ProtocolRuntimeState();

  /// Current protocol configuration.
  /// Configuração atual do protocolo.
  static ObserverProtocolConfig get config => _state.config;

  /// Whether instrumentation is active.
  /// Se a instrumentação está ativa.
  static bool get isEnabled => _state.isEnabled;

  /// Identity of the current isolated protocol session.
  /// Identidade da sessão isolada atual.
  static String get sessionId => _state.sessionId;

  /// Last sequence assigned in the current session.
  /// Última sequência atribuída na sessão atual.
  static int get lastSequenceNumber => _state.lastSequenceNumber;

  /// Events evicted or rejected by the bounded buffer.
  /// Eventos removidos ou rejeitados pelo buffer limitado.
  static int get droppedEventCount => _state.buffer.droppedCount;

  /// Immutable buffered events, oldest first.
  /// Eventos imutáveis no buffer, do mais antigo ao mais recente.
  static List<ObserverProtocolEvent> get events => _state.buffer.events;

  /// Allocates a process-unique monotonic node identity.
  /// Aloca uma identidade monotônica única no processo.
  static ObserverNodeId allocateNodeId() => _state.allocateNodeId();

  /// Applies [config] and begins a clean session.
  /// Aplica [config] e inicia uma sessão limpa.
  static void configure(ObserverProtocolConfig config) =>
      _state.configure(config);

  /// Clears all protocol state and begins a new session.
  /// Limpa todo o estado e inicia uma nova sessão.
  static void startNewSession({String? sessionId}) =>
      _state.startNewSession(explicitSessionId: sessionId);

  /// Restores disabled defaults and clears every retained protocol entry.
  /// Restaura padrões desativados e limpa toda entrada retida.
  static void reset() => _state.reset();

  /// Registers and emits creation of an instrumented node.
  /// Registra e emite a criação de um nó instrumentado.
  static void nodeCreated({
    required ObserverNodeId objectId,
    required ObserverNodeKind kind,
    required String debugLabel,
    required String debugType,
    Object? initialValue,
    bool hasInitialValue = false,
  }) => NodeProtocolRuntime.created(
    _state,
    objectId: objectId,
    kind: kind,
    debugLabel: debugLabel,
    debugType: debugType,
    initialValue: initialValue,
    hasInitialValue: hasInitialValue,
  );

  /// Stores a lazily produced initial value without emitting an update.
  /// Armazena valor inicial lazy sem emitir atualização.
  static void initializeNodeValue(ObserverNodeId objectId, Object? value) =>
      NodeProtocolRuntime.initializeValue(_state, objectId, value);

  /// Updates registry state and emits an actual node value change.
  /// Atualiza o registry e emite uma mudança real de valor.
  static void nodeUpdated({
    required ObserverNodeId objectId,
    required ObserverNodeKind kind,
    required Object? oldValue,
    required Object? newValue,
  }) => NodeProtocolRuntime.updated(
    _state,
    objectId: objectId,
    kind: kind,
    oldValue: oldValue,
    newValue: newValue,
  );

  /// Removes a node from current state and emits its lifecycle end.
  /// Remove um nó do estado atual e emite o fim do lifecycle.
  static void nodeDisposed({
    required ObserverNodeId objectId,
    required ObserverNodeKind kind,
    int listenerCount = 0,
    String? disposeReason,
  }) => NodeProtocolRuntime.disposed(
    _state,
    objectId: objectId,
    kind: kind,
    listenerCount: listenerCount,
    disposeReason: disposeReason,
  );

  /// Creates the lightweight descriptor used to instrument tracked runs.
  /// Cria o descritor leve usado nas execuções rastreadas.
  static ObserverProtocolTracker tracker({
    required ObserverNodeId trackerId,
    required ObserverNodeKind kind,
  }) => TrackerProtocolRuntime.tracker(trackerId: trackerId, kind: kind);

  /// Emits tracker start and returns its finish token.
  /// Emite o início do tracker e retorna seu token de finalização.
  static ObserverProtocolRun? beginTrackerRun(
    ObserverProtocolTracker tracker,
  ) => TrackerProtocolRuntime.begin(_state, tracker);

  /// Applies a final dependency set and emits delta/finish events.
  /// Aplica as dependências finais e emite eventos de delta/fim.
  static void finishTrackerRun(
    ObserverProtocolRun run, {
    required Set<ObserverNodeId> dependencyIds,
    required bool completedWithError,
  }) => TrackerProtocolRuntime.finish(
    _state,
    run,
    dependencyIds: dependencyIds,
    completedWithError: completedWithError,
  );

  /// Marks a tracker disposed and removes its active dependency edges.
  /// Marca o tracker descartado e remove suas arestas ativas.
  static void disposeTracker(ObserverProtocolTracker tracker) =>
      TrackerProtocolRuntime.dispose(_state, tracker);

  /// Registers and emits creation of a scope.
  /// Registra e emite a criação de um escopo.
  static void scopeCreated({
    required ObserverNodeId scopeId,
    required String debugLabel,
  }) => ScopeProtocolRuntime.created(
    _state,
    scopeId: scopeId,
    debugLabel: debugLabel,
  );

  /// Associates a resource identity with an active scope.
  /// Associa a identidade de um recurso a um escopo ativo.
  static void scopeResourceRegistered({
    required ObserverNodeId scopeId,
    required ObserverNodeId resourceId,
    required ObserverNodeKind resourceKind,
  }) => ScopeProtocolRuntime.resourceRegistered(
    _state,
    scopeId: scopeId,
    resourceId: resourceId,
    resourceKind: resourceKind,
  );

  /// Removes a scope and emits structured disposal counts.
  /// Remove um escopo e emite contagens estruturadas de descarte.
  static void scopeDisposed({
    required ObserverNodeId scopeId,
    required int registeredResourceCount,
    required int disposedResourceCount,
    required int failedDisposeCount,
  }) => ScopeProtocolRuntime.disposed(
    _state,
    scopeId: scopeId,
    registeredResourceCount: registeredResourceCount,
    disposedResourceCount: disposedResourceCount,
    failedDisposeCount: failedDisposeCount,
  );

  /// Emits a structured warning alongside the corresponding legacy path.
  /// Emite warning estruturado junto ao caminho legado correspondente.
  static void warningRaised({
    required String warningCode,
    required String message,
    String? suggestion,
    ObserverNodeId? objectId,
    ObserverWarningSeverity severity = ObserverWarningSeverity.warning,
  }) => ScopeProtocolRuntime.warning(
    _state,
    warningCode: warningCode,
    message: message,
    suggestion: suggestion,
    objectId: objectId,
    severity: severity,
  );

  /// Returns an immutable consistent view at [lastSequenceNumber].
  /// Retorna visão imutável e consistente em [lastSequenceNumber].
  static ObserverProtocolSnapshot snapshot() => _state.snapshot();
}
