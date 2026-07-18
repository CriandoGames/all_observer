import '../model/observer_node.dart';
import 'observer_protocol_event.dart';

/// Severity carried by a structured protocol warning.
/// Severidade carregada por um warning estruturado.
enum ObserverWarningSeverity {
  /// Informational diagnostic.
  /// Diagnóstico informativo.
  info,

  /// Recoverable misuse warning.
  /// Warning recuperável de mau uso.
  warning,

  /// Error-level diagnostic.
  /// Diagnóstico em nível de erro.
  error,
}

/// Structured diagnostic corresponding to an existing warning path.
/// Diagnóstico estruturado correspondente a um warning existente.
final class WarningRaisedEvent extends ObserverProtocolEvent {
  /// Creates a structured warning event.
  /// Cria um evento estruturado de warning.
  const WarningRaisedEvent({
    required super.protocolVersion,
    required super.sessionId,
    required super.eventId,
    required super.sequenceNumber,
    required super.timestampMicros,
    required this.warningCode,
    required this.message,
    required this.severity,
    this.suggestion,
    this.objectId,
    super.stackTrace,
  });

  /// Stable machine-readable warning category.
  /// Categoria estável legível por máquina.
  final String warningCode;

  /// Human-readable warning message.
  /// Mensagem legível do warning.
  final String message;

  /// Optional corrective guidance.
  /// Orientação corretiva opcional.
  final String? suggestion;

  /// Related node identity when known.
  /// Identidade do nó relacionado, quando conhecida.
  final ObserverNodeId? objectId;

  /// Diagnostic severity.
  /// Severidade do diagnóstico.
  final ObserverWarningSeverity severity;
}
