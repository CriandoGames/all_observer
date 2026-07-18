import '../model/observer_node.dart';
import 'observer_protocol_event.dart';

/// Announces creation of a reactive resource scope.
/// Anuncia a criação de um escopo de recursos reativos.
final class ScopeCreatedEvent extends ObserverProtocolEvent {
  /// Creates a scope-created event.
  /// Cria um evento de criação de escopo.
  const ScopeCreatedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.scopeId,
    required this.debugLabel,
    super.stackTrace,
  });

  /// Stable scope identity.
  /// Identidade estável do escopo.
  final ObserverNodeId scopeId;

  /// Human-readable scope label.
  /// Rótulo legível do escopo.
  final String debugLabel;
}

/// Reports ownership of a resource by an active scope.
/// Reporta que um recurso pertence a um escopo ativo.
final class ScopeResourceRegisteredEvent extends ObserverProtocolEvent {
  /// Creates a scope-resource-registration event.
  /// Cria um evento de registro de recurso em escopo.
  const ScopeResourceRegisteredEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.scopeId,
    required this.resourceId,
    required this.resourceKind,
    super.stackTrace,
  });

  /// Stable owner scope identity.
  /// Identidade estável do escopo dono.
  final ObserverNodeId scopeId;

  /// Stable resource identity.
  /// Identidade estável do recurso.
  final ObserverNodeId resourceId;

  /// Logical resource role.
  /// Papel lógico do recurso.
  final ObserverNodeKind resourceKind;
}

/// Structured scope-disposal result, distinct from the legacy event type.
/// Resultado estruturado de descarte, distinto do evento legado.
final class ProtocolScopeDisposedEvent extends ObserverProtocolEvent {
  /// Creates a protocol scope-disposed event.
  /// Cria um evento de descarte de escopo do protocolo.
  const ProtocolScopeDisposedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.scopeId,
    required this.registeredResourceCount,
    required this.disposedResourceCount,
    required this.failedDisposeCount,
    super.stackTrace,
  });

  /// Stable disposed scope identity.
  /// Identidade estável do escopo descartado.
  final ObserverNodeId scopeId;

  /// Resources registered when disposal began.
  /// Recursos registrados quando o descarte começou.
  final int registeredResourceCount;

  /// Resources whose disposer completed normally.
  /// Recursos cujo disposer terminou normalmente.
  final int disposedResourceCount;

  /// Resources whose disposer threw and was isolated.
  /// Recursos cujo disposer lançou e foi isolado.
  final int failedDisposeCount;
}
