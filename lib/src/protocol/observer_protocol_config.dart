/// Isolated configuration for Observer Protocol instrumentation.
///
/// Configuração isolada da instrumentação do Observer Protocol.
final class ObserverProtocolConfig {
  /// Creates protocol configuration. Instrumentation is disabled by default.
  ///
  /// Cria a configuração do protocolo. A instrumentação vem desativada.
  const ObserverProtocolConfig({
    this.enabled = false,
    this.captureValues = false,
    this.captureStackTraces = false,
    this.eventBufferSize = 1000,
    this.registryEnabled = true,
    this.maxStringLength = 120,
    this.redactValue,
    this.redactLabels = false,
  }) : assert(eventBufferSize >= 0),
       assert(maxStringLength >= 0);

  /// Conservative preset for diagnostics that may be enabled in production.
  const ObserverProtocolConfig.productionSafe({
    this.enabled = true,
    this.eventBufferSize = 1000,
    this.registryEnabled = true,
    this.maxStringLength = 120,
    this.redactValue,
  }) : captureValues = false,
       captureStackTraces = false,
       redactLabels = true,
       assert(eventBufferSize >= 0),
       assert(maxStringLength >= 0);

  /// Whether protocol instrumentation is active.
  ///
  /// Se a instrumentação do protocolo está ativa.
  final bool enabled;

  /// Whether safe primitive displays and collection sizes are captured.
  ///
  /// Se exibições de primitivos seguros e tamanhos de coleções são capturados.
  final bool captureValues;

  /// Whether protocol events capture a stack trace.
  ///
  /// Se os eventos do protocolo capturam stack trace.
  final bool captureStackTraces;

  /// Maximum retained event count. Zero retains no events.
  ///
  /// Máximo de eventos retidos. Zero não retém eventos.
  final int eventBufferSize;

  /// Whether current nodes, dependencies and scopes are retained.
  ///
  /// Se nós, dependências e escopos atuais são retidos.
  final bool registryEnabled;

  /// Maximum displayed string length when [captureValues] is enabled.
  ///
  /// Tamanho máximo de string exibida quando [captureValues] está ativo.
  final int maxStringLength;

  /// Optional application policy that forces a value summary to be redacted.
  /// A throwing policy fails closed and also redacts the value.
  ///
  /// Política opcional que força a redação do resumo. Se ela lançar, o valor
  /// também será redigido por segurança.
  final bool Function(Object? value)? redactValue;

  /// Whether user-provided node and scope labels are replaced before storage.
  final bool redactLabels;
}
