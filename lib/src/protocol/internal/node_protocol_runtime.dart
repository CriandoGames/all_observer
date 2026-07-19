import '../events/node_events.dart';
import '../events/observer_protocol_event.dart';
import '../model/observer_node.dart';
import '../model/observer_value_summary.dart';
import '../snapshot/observer_protocol_snapshot.dart';
import 'protocol_runtime_state.dart';
import 'value_summary_policy.dart';

/// Node lifecycle operations separated from session/tracker/scope concerns.
///
/// Operações de lifecycle de nós separadas de sessão, trackers e escopos.
abstract final class NodeProtocolRuntime {
  /// Registers metadata and emits node creation.
  ///
  /// Registra metadados e emite a criação do nó.
  static void created(
    ProtocolRuntimeState state, {
    required ObserverNodeId objectId,
    required ObserverNodeKind kind,
    required String debugLabel,
    required String debugType,
    Object? initialValue,
    bool hasInitialValue = false,
  }) {
    if (!state.isEnabled) return;
    try {
      final ProtocolEventMetadata meta = state.metadata();
      final ObserverValueSummary? summary = hasInitialValue
          ? ValueSummaryPolicy.summarize(initialValue, state.config)
          : null;
      final String safeLabel = state.config.redactLabels
          ? '[redacted]'
          : debugLabel;
      if (state.config.registryEnabled) {
        state.registry.registerNode(
          ObserverNodeSnapshot(
            objectId: objectId,
            kind: kind,
            debugLabel: safeLabel,
            debugType: debugType,
            createdAtMicros: meta.timestampMicros,
            valueSummary: summary,
          ),
        );
      }
      state.emit(
        NodeCreatedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          objectId: objectId,
          kind: kind,
          debugLabel: safeLabel,
          debugType: debugType,
          initialValueSummary: summary,
        ),
      );
    } catch (_) {}
  }

  /// Stores the first lazy value without reporting an update.
  ///
  /// Armazena o primeiro valor lazy sem reportar atualização.
  static void initializeValue(
    ProtocolRuntimeState state,
    ObserverNodeId objectId,
    Object? value,
  ) {
    if (!state.isEnabled || !state.config.registryEnabled) return;
    try {
      state.registry.updateNodeValue(
        objectId,
        ValueSummaryPolicy.summarize(value, state.config),
      );
    } catch (_) {}
  }

  /// Replaces the safe value summary and emits an update.
  ///
  /// Substitui o resumo seguro e emite uma atualização.
  static void updated(
    ProtocolRuntimeState state, {
    required ObserverNodeId objectId,
    required ObserverNodeKind kind,
    required Object? oldValue,
    required Object? newValue,
  }) {
    if (!state.isEnabled) return;
    try {
      final ObserverValueSummary oldSummary = ValueSummaryPolicy.summarize(
        oldValue,
        state.config,
      );
      final ObserverValueSummary newSummary = ValueSummaryPolicy.summarize(
        newValue,
        state.config,
      );
      if (state.config.registryEnabled) {
        state.registry.updateNodeValue(objectId, newSummary);
      }
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        NodeUpdatedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          objectId: objectId,
          kind: kind,
          oldValueSummary: oldSummary,
          newValueSummary: newSummary,
        ),
      );
    } catch (_) {}
  }

  /// Removes node metadata and emits disposal.
  ///
  /// Remove os metadados e emite o descarte do nó.
  static void disposed(
    ProtocolRuntimeState state, {
    required ObserverNodeId objectId,
    required ObserverNodeKind kind,
    int listenerCount = 0,
    String? disposeReason,
  }) {
    if (!state.isEnabled) return;
    try {
      state.registry.disposeNode(objectId);
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        NodeDisposedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          objectId: objectId,
          kind: kind,
          listenerCount: listenerCount,
          disposeReason: disposeReason,
        ),
      );
    } catch (_) {}
  }
}
