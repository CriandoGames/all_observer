import '../model/observer_node.dart';
import 'observer_protocol_event.dart';

/// Marks the beginning of one tracked callback execution.
/// Marca o início de uma execução rastreada.
final class TrackerRunStartedEvent extends ObserverProtocolEvent {
  /// Creates a tracker-run-started event.
  /// Cria um evento de início de tracker.
  const TrackerRunStartedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.trackerId,
    required this.runId,
    required this.kind,
    super.stackTrace,
  });

  /// Stable identity of the tracker node.
  /// Identidade estável do tracker.
  final ObserverNodeId trackerId;

  /// Identity unique to this execution.
  /// Identidade única desta execução.
  final String runId;

  /// Logical tracker role.
  /// Papel lógico do tracker.
  final ObserverNodeKind kind;
}

/// Marks the end of a tracked callback, including exceptional exits.
/// Marca o fim de um callback, inclusive quando ele lança.
final class TrackerRunFinishedEvent extends ObserverProtocolEvent {
  /// Creates a tracker-run-finished event.
  /// Cria um evento de fim de tracker.
  TrackerRunFinishedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.trackerId,
    required this.runId,
    required this.kind,
    required this.durationMicros,
    required Set<ObserverNodeId> dependencyIds,
    required this.completedWithError,
    super.stackTrace,
  }) : dependencyIds = Set<ObserverNodeId>.unmodifiable(dependencyIds);

  /// Stable identity of the tracker node.
  /// Identidade estável do tracker.
  final ObserverNodeId trackerId;

  /// Identity shared with the matching start event.
  /// Identidade compartilhada com o início correspondente.
  final String runId;

  /// Logical tracker role.
  /// Papel lógico do tracker.
  final ObserverNodeKind kind;

  /// Monotonic elapsed duration in microseconds.
  /// Duração monotônica em microssegundos.
  final int durationMicros;

  /// Deduplicated final dependency set.
  /// Conjunto final deduplicado de dependências.
  final Set<ObserverNodeId> dependencyIds;

  /// Whether the original callback exited by throwing.
  /// Se o callback original terminou lançando.
  final bool completedWithError;
}

/// Reports the complete dependency delta after a tracked run.
/// Reporta o delta completo após uma execução rastreada.
final class DependenciesChangedEvent extends ObserverProtocolEvent {
  /// Creates an immutable dependency-change event.
  /// Cria um evento imutável de mudança de dependências.
  DependenciesChangedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.trackerId,
    required this.runId,
    required Set<ObserverNodeId> currentDependencyIds,
    required Set<ObserverNodeId> addedDependencyIds,
    required Set<ObserverNodeId> removedDependencyIds,
    super.stackTrace,
  }) : currentDependencyIds = Set<ObserverNodeId>.unmodifiable(
         currentDependencyIds,
       ),
       addedDependencyIds = Set<ObserverNodeId>.unmodifiable(
         addedDependencyIds,
       ),
       removedDependencyIds = Set<ObserverNodeId>.unmodifiable(
         removedDependencyIds,
       );

  /// Stable tracker identity.
  /// Identidade estável do tracker.
  final ObserverNodeId trackerId;

  /// Execution that produced this delta.
  /// Execução que produziu este delta.
  final String runId;

  /// Complete active dependency set after the run.
  /// Conjunto completo de dependências ativas após a execução.
  final Set<ObserverNodeId> currentDependencyIds;

  /// Dependencies absent before and present now.
  /// Dependências ausentes antes e presentes agora.
  final Set<ObserverNodeId> addedDependencyIds;

  /// Dependencies present before and absent now.
  /// Dependências presentes antes e ausentes agora.
  final Set<ObserverNodeId> removedDependencyIds;
}
