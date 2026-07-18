import '../events/observer_protocol_event.dart';
import '../events/scope_events.dart';
import '../events/warning_event.dart';
import '../model/observer_node.dart';
import 'protocol_runtime_state.dart';

/// Scope ownership and structured-warning operations.
///
/// Operações de ownership de escopos e warnings estruturados.
abstract final class ScopeProtocolRuntime {
  /// Registers and emits scope creation.
  ///
  /// Registra e emite a criação do escopo.
  static void created(
    ProtocolRuntimeState state, {
    required ObserverNodeId scopeId,
    required String debugLabel,
  }) {
    if (!state.isEnabled) return;
    try {
      if (state.config.registryEnabled) {
        state.registry.registerScope(scopeId, debugLabel);
      }
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        ScopeCreatedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          scopeId: scopeId,
          debugLabel: debugLabel,
        ),
      );
    } catch (_) {}
  }

  /// Associates and emits a scope-owned resource.
  ///
  /// Associa e emite um recurso pertencente ao escopo.
  static void resourceRegistered(
    ProtocolRuntimeState state, {
    required ObserverNodeId scopeId,
    required ObserverNodeId resourceId,
    required ObserverNodeKind resourceKind,
  }) {
    if (!state.isEnabled) return;
    try {
      if (state.config.registryEnabled) {
        state.registry.registerScopeResource(scopeId, resourceId, resourceKind);
      }
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        ScopeResourceRegisteredEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          scopeId: scopeId,
          resourceId: resourceId,
          resourceKind: resourceKind,
        ),
      );
    } catch (_) {}
  }

  /// Removes the scope and emits disposal counters.
  ///
  /// Remove o escopo e emite as contagens de descarte.
  static void disposed(
    ProtocolRuntimeState state, {
    required ObserverNodeId scopeId,
    required int registeredResourceCount,
    required int disposedResourceCount,
    required int failedDisposeCount,
  }) {
    if (!state.isEnabled) return;
    try {
      state.registry.disposeScope(scopeId);
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        ProtocolScopeDisposedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          scopeId: scopeId,
          registeredResourceCount: registeredResourceCount,
          disposedResourceCount: disposedResourceCount,
          failedDisposeCount: failedDisposeCount,
        ),
      );
    } catch (_) {}
  }

  /// Emits a warning through the protocol stream.
  ///
  /// Emite um warning pelo stream do protocolo.
  static void warning(
    ProtocolRuntimeState state, {
    required String warningCode,
    required String message,
    String? suggestion,
    ObserverNodeId? objectId,
    ObserverWarningSeverity severity = ObserverWarningSeverity.warning,
  }) {
    if (!state.isEnabled) return;
    try {
      final ProtocolEventMetadata meta = state.metadata();
      state.emit(
        WarningRaisedEvent(
          protocolVersion: observerProtocolVersion,
          sessionId: meta.sessionId,
          eventId: meta.eventId,
          sequenceNumber: meta.sequenceNumber,
          timestampMicros: meta.timestampMicros,
          stackTrace: meta.stackTrace,
          warningCode: warningCode,
          message: message,
          suggestion: suggestion,
          objectId: objectId,
          severity: severity,
        ),
      );
    } catch (_) {}
  }
}
