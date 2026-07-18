/// Safe, bounded description of a value; never retains the original value.
///
/// Descrição segura e limitada; nunca retém o valor original.
final class ObserverValueSummary {
  /// Creates a value summary.
  ///
  /// Cria um resumo de valor.
  const ObserverValueSummary({
    required this.type,
    this.display,
    this.isRedacted = false,
    this.isTruncated = false,
  });

  /// Runtime type name.
  ///
  /// Nome do tipo em runtime.
  final String type;

  /// Optional bounded display text for safe values.
  ///
  /// Texto opcional e limitado para valores seguros.
  final String? display;

  /// Whether display text was withheld as sensitive.
  ///
  /// Se o texto foi omitido por ser sensível.
  final bool isRedacted;

  /// Whether [display] was shortened to the configured limit.
  ///
  /// Se [display] foi truncado no limite configurado.
  final bool isTruncated;
}
