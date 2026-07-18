import '../events/observer_protocol_event.dart';
import '../events/tracker_events.dart';
import '../model/observer_node.dart';
import '../observer_protocol_tracking.dart';
import 'protocol_registry.dart';
import 'protocol_runtime_state.dart';

/// Tracker run and dependency-delta operations.
///
/// Operações de execução de trackers e delta de dependências.
abstract final class TrackerProtocolRuntime {
  /// Creates a lightweight tracker descriptor.
  ///
  /// Cria um descritor leve de tracker.
  static ObserverProtocolTracker tracker({
    required ObserverNodeId trackerId,
    required ObserverNodeKind kind,
  }) => ObserverProtocolTracker(trackerId: trackerId, kind: kind);

  /// Emits run start and returns its pairing token.
  ///
  /// Emite o início da execução e retorna seu token de pareamento.
  static ObserverProtocolRun? begin(
    ProtocolRuntimeState state,
    ObserverProtocolTracker tracker,
  ) {
    if (!state.isEnabled || state.disposedTrackers[tracker] == true) {
      return null;
    }
    try {
      final String runId = state.allocateRunId();
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        TrackerRunStartedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          trackerId: tracker.trackerId,
          runId: runId,
          kind: tracker.kind,
        ),
      );
      return ObserverProtocolRun(
        tracker: tracker,
        runId: runId,
        startedAtMicros: state.monotonicClock.elapsedMicroseconds,
      );
    } catch (_) {
      return null;
    }
  }

  /// Applies final dependencies and emits delta/finish.
  ///
  /// Aplica as dependências finais e emite delta/fim.
  static void finish(
    ProtocolRuntimeState state,
    ObserverProtocolRun run, {
    required Set<ObserverNodeId> dependencyIds,
    required bool completedWithError,
  }) {
    if (!state.isEnabled) return;
    try {
      final Set<ObserverNodeId> current =
          state.disposedTrackers[run.tracker] == true
          ? <ObserverNodeId>{}
          : Set<ObserverNodeId>.of(dependencyIds);
      if (!state.config.registryEnabled) {
        _emitFinished(
          state,
          run,
          current: current,
          completedWithError: completedWithError,
        );
        return;
      }
      final ProtocolDependencyDelta delta = state.registry.replaceDependencies(
        run.tracker.trackerId,
        current,
      );
      if (delta.added.isNotEmpty || delta.removed.isNotEmpty) {
        final ProtocolEventMetadata changed = state.metadata();
        state.emit(
          DependenciesChangedEvent(
            protocolVersion: observerProtocolVersion,
            sessionId: changed.sessionId,
            eventId: changed.eventId,
            sequenceNumber: changed.sequenceNumber,
            timestampMicros: changed.timestampMicros,
            stackTrace: changed.stackTrace,
            trackerId: run.tracker.trackerId,
            runId: run.runId,
            currentDependencyIds: current,
            addedDependencyIds: delta.added,
            removedDependencyIds: delta.removed,
          ),
        );
      }
      _emitFinished(
        state,
        run,
        current: current,
        completedWithError: completedWithError,
      );
    } catch (_) {}
  }

  static void _emitFinished(
    ProtocolRuntimeState state,
    ObserverProtocolRun run, {
    required Set<ObserverNodeId> current,
    required bool completedWithError,
  }) {
    final ProtocolEventMetadata finished = state.metadata();
    state.emit(
      TrackerRunFinishedEvent(
        protocolVersion: observerProtocolVersion,
        sessionId: finished.sessionId,
        eventId: finished.eventId,
        sequenceNumber: finished.sequenceNumber,
        timestampMicros: finished.timestampMicros,
        stackTrace: finished.stackTrace,
        trackerId: run.tracker.trackerId,
        runId: run.runId,
        kind: run.tracker.kind,
        durationMicros:
            state.monotonicClock.elapsedMicroseconds - run.startedAtMicros,
        dependencyIds: current,
        completedWithError: completedWithError,
      ),
    );
  }

  /// Marks a tracker disposed and removes its edges.
  ///
  /// Marca o tracker descartado e remove suas arestas.
  static void dispose(
    ProtocolRuntimeState state,
    ObserverProtocolTracker tracker,
  ) {
    state.disposedTrackers[tracker] = true;
    state.registry.disposeTracker(tracker.trackerId);
  }
}
