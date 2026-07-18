import '../../core/core_error_reporting.dart';
import '../../logging/observer_config.dart';
import '../events/observer_protocol_event.dart';
import '../model/observer_node.dart';
import '../observer_protocol_config.dart';
import '../observer_protocol_inspector.dart';
import '../snapshot/observer_protocol_snapshot.dart';
import 'protocol_event_buffer.dart';
import 'protocol_registry.dart';

/// Shared mutable session state used by the focused protocol runtimes.
///
/// Estado mutável da sessão compartilhado pelos runtimes especializados.
final class ProtocolRuntimeState {
  /// Active configuration. / Configuração ativa.
  ObserverProtocolConfig config = const ObserverProtocolConfig();

  /// Bounded event storage. / Armazenamento limitado de eventos.
  final ProtocolEventBuffer buffer = ProtocolEventBuffer(1000);

  /// Current metadata registry. / Registry de metadados atuais.
  final ProtocolRegistry registry = ProtocolRegistry();

  /// Monotonic duration source. / Fonte monotônica de duração.
  final Stopwatch monotonicClock = Stopwatch()..start();

  /// Weak disposal flags for trackers. / Flags fracas de descarte de trackers.
  final Expando<bool> disposedTrackers = Expando<bool>(
    'all_observer protocol tracker disposal',
  );

  int _globalNodeCounter = 0;
  int _sessionCounter = 0;
  int _sequenceNumber = 0;
  int _eventCounter = 0;
  int _runCounter = 0;

  /// Current session identity. / Identidade da sessão atual.
  late String sessionId = _generateSessionId();

  /// Whether instrumentation is enabled. / Se a instrumentação está ativa.
  bool get isEnabled => config.enabled;

  /// Last allocated sequence. / Última sequência alocada.
  int get lastSequenceNumber => _sequenceNumber;

  /// Allocates a stable node ID. / Aloca um ID estável de nó.
  ObserverNodeId allocateNodeId() => ObserverNodeId(++_globalNodeCounter);

  /// Allocates a session run ID. / Aloca um ID de execução na sessão.
  String allocateRunId() => 'run-${++_runCounter}';

  /// Applies configuration and starts clean. / Aplica configuração e reinicia.
  void configure(ObserverProtocolConfig next) {
    config = next;
    // The public constructor asserts this in debug mode; clamping here keeps
    // an invalid release-mode value from accidentally creating an unbounded
    // queue. / O construtor valida em debug; o clamp impede que um valor
    // inválido em release transforme a fila em armazenamento ilimitado.
    buffer.limit = next.eventBufferSize < 0 ? 0 : next.eventBufferSize;
    startNewSession();
  }

  /// Starts an isolated session. / Inicia uma sessão isolada.
  void startNewSession({String? explicitSessionId}) {
    sessionId = explicitSessionId ?? _generateSessionId();
    _sequenceNumber = 0;
    _eventCounter = 0;
    _runCounter = 0;
    buffer.clear();
    registry.clear();
  }

  /// Restores disabled defaults. / Restaura os padrões desativados.
  void reset() => configure(const ObserverProtocolConfig());

  /// Allocates one event envelope. / Aloca um envelope de evento.
  ProtocolEventMetadata metadata() => ProtocolEventMetadata(
    sessionId: sessionId,
    eventId: 'event-${++_eventCounter}',
    sequenceNumber: ++_sequenceNumber,
    timestampMicros: DateTime.now().microsecondsSinceEpoch,
    stackTrace: config.captureStackTraces ? StackTrace.current : null,
  );

  /// Buffers and dispatches [event]. / Armazena e despacha [event].
  void emit(ObserverProtocolEvent event) {
    buffer.add(event);
    if (ObserverConfig.inspectors.isEmpty) return;
    for (final inspector in List.of(ObserverConfig.inspectors)) {
      if (inspector is ObserverProtocolInspector) {
        try {
          inspector.onProtocolEvent(event);
        } catch (error, stackTrace) {
          // Diagnostics cannot affect application state or later inspectors.
          // Report through the same pure-Dart hook used by the reactive core.
          try {
            CoreErrorReporting.report(
              error,
              stackTrace,
              library: 'all_observer',
              context: 'while dispatching an Observer Protocol event',
            );
          } catch (_) {
            // A failing host reporter is diagnostic code too and stays isolated.
          }
        }
      }
    }
  }

  /// Builds a consistent snapshot. / Constrói um snapshot consistente.
  ObserverProtocolSnapshot snapshot() => ObserverProtocolSnapshot(
    protocolVersion: observerProtocolVersion,
    sessionId: sessionId,
    generatedAtMicros: DateTime.now().microsecondsSinceEpoch,
    lastSequenceNumber: _sequenceNumber,
    nodes: config.registryEnabled
        ? registry.nodeSnapshots()
        : <ObserverNodeSnapshot>[],
    dependencies: config.registryEnabled
        ? registry.dependencySnapshots()
        : <ObserverDependencySnapshot>[],
    scopes: config.registryEnabled
        ? registry.scopeSnapshots()
        : <ObserverScopeSnapshot>[],
    droppedEventCount: buffer.droppedCount,
    firstAvailableSequence: buffer.firstAvailableSequence,
    lastAvailableSequence: buffer.lastAvailableSequence,
  );

  String _generateSessionId() =>
      'session-${DateTime.now().microsecondsSinceEpoch}-${++_sessionCounter}';
}

/// Common event envelope values allocated atomically by the session state.
///
/// Valores comuns do envelope alocados atomicamente pela sessão.
final class ProtocolEventMetadata {
  /// Creates envelope metadata. / Cria metadados do envelope.
  const ProtocolEventMetadata({
    required this.sessionId,
    required this.eventId,
    required this.sequenceNumber,
    required this.timestampMicros,
    required this.stackTrace,
  });

  /// Session identity. / Identidade da sessão.
  final String sessionId;

  /// Event identity. / Identidade do evento.
  final String eventId;

  /// Global session order. / Ordem global na sessão.
  final int sequenceNumber;

  /// Wall-clock microseconds. / Microssegundos do relógio de parede.
  final int timestampMicros;

  /// Optional captured stack. / Stack opcional capturado.
  final StackTrace? stackTrace;
}
