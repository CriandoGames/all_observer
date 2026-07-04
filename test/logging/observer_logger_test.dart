import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/logging/observer_logger.dart';

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('ObserverLogger warnings', () {
    test('emits a warning for an Observer that tracked nothing', () {
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn(
          'Observer(x) não leu nenhum Observable no builder.',
          suggestion: 'Você esqueceu o `.value`?',
        );
      } finally {
        debugPrint = original;
      }
      expect(lines, hasLength(1));
      expect(lines.single, contains('não leu nenhum Observable'));
      expect(lines.single, contains('Você esqueceu o `.value`?'));
    });

    test('emits a warning for writes on a disposed observable', () {
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn('já descartado. Ignorado.');
      } finally {
        debugPrint = original;
      }
      expect(lines.single, contains('descartado'));
    });

    test('emits a warning for writes during build', () {
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn('alterado DURANTE o build de um Observer.');
      } finally {
        debugPrint = original;
      }
      expect(lines.single, contains('DURANTE o build'));
    });

    test('emits a warning for a probable listener leak', () {
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn('tem 50+ listeners. Possível vazamento.');
      } finally {
        debugPrint = original;
      }
      expect(lines.single, contains('Possível vazamento'));
    });

    test('warnings are suppressed when ObserverConfig.warnings is false', () {
      ObserverConfig.warnings = false;
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn('não deveria aparecer');
      } finally {
        debugPrint = original;
      }
      expect(lines, isEmpty);
    });
  });

  group('ObserverLogger useColors', () {
    test('useColors=false removes ANSI escape codes from output', () {
      ObserverConfig.useColors = false;
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn('mensagem sem cor');
      } finally {
        debugPrint = original;
      }
      expect(lines.single, isNot(contains('\x1B[')));
    });

    test('useColors=true (default) includes ANSI escape codes', () {
      final List<String> lines = <String>[];
      final void Function(String?, {int? wrapWidth}) original = debugPrint;
      debugPrint = (String? message, {int? wrapWidth}) {
        if (message != null) lines.add(message);
      };
      try {
        ObserverLogger.warn('mensagem colorida');
      } finally {
        debugPrint = original;
      }
      expect(lines.single, contains('\x1B['));
    });
  });
}
