import 'dart:typed_data';

import '../model/observer_value_summary.dart';
import '../observer_protocol_config.dart';

/// Bounded, non-recursive value representation policy.
///
/// Política limitada e não recursiva de representação de valores.
abstract final class ValueSummaryPolicy {
  /// Produces a safe summary according to [config].
  ///
  /// Produz um resumo seguro conforme [config].
  static ObserverValueSummary summarize(
    Object? value,
    ObserverProtocolConfig config,
  ) {
    final String type = value == null ? 'Null' : value.runtimeType.toString();
    if (!config.captureValues) {
      return ObserverValueSummary(type: type);
    }
    try {
      final bool Function(Object? value)? redactValue = config.redactValue;
      if (redactValue != null && redactValue(value)) {
        return ObserverValueSummary(type: type, isRedacted: true);
      }
      if (value == null) {
        return const ObserverValueSummary(type: 'Null', display: 'null');
      }
      if (value is bool || value is num) {
        return ObserverValueSummary(type: type, display: '$value');
      }
      if (value is String) {
        if (_looksSensitive(value)) {
          return ObserverValueSummary(type: type, isRedacted: true);
        }
        final bool truncated = value.length > config.maxStringLength;
        return ObserverValueSummary(
          type: type,
          display: truncated
              ? value.substring(0, config.maxStringLength)
              : value,
          isTruncated: truncated,
        );
      }
      if (value is Enum) {
        return ObserverValueSummary(type: type, display: value.name);
      }
      if (value is Uint8List) {
        return ObserverValueSummary(
          type: type,
          display: 'Uint8List(length: ${value.length})',
        );
      }
      if (value is List<Object?>) {
        return ObserverValueSummary(
          type: type,
          display: '$type(length: ${value.length})',
        );
      }
      if (value is Map<Object?, Object?>) {
        return ObserverValueSummary(
          type: type,
          display: '$type(length: ${value.length})',
        );
      }
      if (value is Set<Object?>) {
        return ObserverValueSummary(
          type: type,
          display: '$type(length: ${value.length})',
        );
      }
    } catch (_) {
      return ObserverValueSummary(
        type: type,
        isRedacted: config.redactValue != null,
      );
    }
    return ObserverValueSummary(type: type);
  }

  static bool _looksSensitive(String value) {
    final String lower = value.toLowerCase();
    return lower.contains('password') ||
        lower.contains('passwd') ||
        lower.contains('secret') ||
        lower.contains('token=') ||
        lower.contains('authorization:') ||
        lower.contains('bearer ');
  }
}
