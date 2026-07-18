import '../model/observer_node.dart';
import '../model/observer_value_summary.dart';
import 'observer_protocol_event.dart';

/// Announces an instrumented node and its stable identity.
///
/// Anuncia um nó instrumentado e sua identidade estável.
final class NodeCreatedEvent extends ObserverProtocolEvent {
  /// Creates a node-created event.
  /// Cria um evento de criação de nó.
  const NodeCreatedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.objectId,
    required this.kind,
    required this.debugLabel,
    required this.debugType,
    this.initialValueSummary,
    super.stackTrace,
  });

  /// Stable node identity.
  /// Identidade estável do nó.
  final ObserverNodeId objectId;

  /// Logical node role.
  /// Papel lógico do nó.
  final ObserverNodeKind kind;

  /// Human-readable label, never used as identity.
  /// Rótulo legível, nunca usado como identidade.
  final String debugLabel;

  /// Runtime type used only for diagnostics.
  /// Tipo em runtime usado apenas para diagnóstico.
  final String debugType;

  /// Safe initial value summary when the node has an initial value.
  /// Resumo seguro do valor inicial, quando existente.
  final ObserverValueSummary? initialValueSummary;
}

/// Reports an actual value change after the existing equality filter.
///
/// Reporta mudança real após o filtro de igualdade existente.
final class NodeUpdatedEvent extends ObserverProtocolEvent {
  /// Creates a node-updated event.
  /// Cria um evento de atualização de nó.
  const NodeUpdatedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.objectId,
    required this.kind,
    this.oldValueSummary,
    this.newValueSummary,
    super.stackTrace,
  });

  /// Stable node identity.
  /// Identidade estável do nó.
  final ObserverNodeId objectId;

  /// Logical node role.
  /// Papel lógico do nó.
  final ObserverNodeKind kind;

  /// Safe summary of the previous value.
  /// Resumo seguro do valor anterior.
  final ObserverValueSummary? oldValueSummary;

  /// Safe summary of the current value.
  /// Resumo seguro do valor atual.
  final ObserverValueSummary? newValueSummary;
}

/// Announces the idempotent disposal of a node.
///
/// Anuncia o descarte idempotente de um nó.
final class NodeDisposedEvent extends ObserverProtocolEvent {
  /// Creates a node-disposed event.
  /// Cria um evento de descarte de nó.
  const NodeDisposedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.objectId,
    required this.kind,
    required this.listenerCount,
    this.disposeReason,
    super.stackTrace,
  });

  /// Stable node identity.
  /// Identidade estável do nó.
  final ObserverNodeId objectId;

  /// Logical node role.
  /// Papel lógico do nó.
  final ObserverNodeKind kind;

  /// Listeners attached immediately before disposal.
  /// Listeners anexados imediatamente antes do descarte.
  final int listenerCount;

  /// Known disposal reason, or `null` when the core has none.
  /// Motivo conhecido, ou `null` quando o core não possui um.
  final String? disposeReason;
}
