/// Thrown only when `ObserverConfig.strictMode` is enabled, in place of the
/// default non-fatal warning, when an [Observer] builder reads no
/// observable and therefore would never rebuild.
///
/// Lançada apenas quando `ObserverConfig.strictMode` está habilitado, no
/// lugar do warning não fatal padrão, quando o builder de um [Observer]
/// não lê nenhum observável e, portanto, nunca reconstruiria.
class ObserverError extends Error {
  /// Creates an [ObserverError] with a human-readable [message].
  ///
  /// Cria um [ObserverError] com uma [message] legível por humanos.
  ObserverError(this.message);

  /// Explanation of what went wrong and how to fix it.
  ///
  /// Explicação do que deu errado e como corrigir.
  final String message;

  @override
  String toString() => 'ObserverError: $message';
}
