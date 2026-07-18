/// Current wire contract version, independent from the package version.
///
/// Versão atual do contrato, independente da versão do pacote.
const int observerProtocolVersion = 1;

/// Versioned envelope shared by every Observer Protocol event.
///
/// Envelope versionado compartilhado por todo evento do Observer Protocol.
abstract base class ObserverProtocolEvent {
  /// Creates an immutable event envelope.
  ///
  /// Cria um envelope imutável de evento.
  const ObserverProtocolEvent({
    required this.protocolVersion,
    required this.sessionId,
    required this.eventId,
    required this.sequenceNumber,
    required this.timestampMicros,
    this.stackTrace,
  });

  /// Protocol schema version.
  /// Versão do schema do protocolo.
  final int protocolVersion;

  /// Identity of the protocol session that produced the event.
  /// Identidade da sessão que produziu o evento.
  final String sessionId;

  /// Unique event identity inside [sessionId].
  /// Identidade única do evento dentro de [sessionId].
  final String eventId;

  /// Strictly increasing order inside [sessionId].
  /// Ordem estritamente crescente dentro de [sessionId].
  final int sequenceNumber;

  /// Wall-clock timestamp from `DateTime.now()`, in microseconds since epoch.
  /// Timestamp de relógio de parede em microssegundos desde epoch.
  final int timestampMicros;

  /// Optional diagnostic stack, captured only when configured.
  /// Stack opcional, capturado apenas quando configurado.
  final StackTrace? stackTrace;
}
