import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/observer_inspector.dart';
import 'package:all_observer/src/core/recording_inspector.dart';
import 'package:all_observer/src/logging/console_inspector.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/logging/observer_logger.dart';

List<String> _captureDebugPrint(void Function() action) {
  final List<String> lines = <String>[];
  final void Function(String?, {int? wrapWidth}) original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) lines.add(message);
  };
  try {
    action();
  } finally {
    debugPrint = original;
  }
  return lines;
}

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('ConsoleInspector', () {
    test('onCreate prints only when logging + lifecycle level allowed', () {
      ObserverConfig.logging = true;
      const ConsoleInspector inspector = ConsoleInspector();
      final List<String> lines = _captureDebugPrint(() {
        inspector.onCreate(ObservableCreateEvent('Observable(x)', 1));
      });
      expect(lines.single, contains('Observable(x) criado'));
    });

    test('onCreate is silent when logging is disabled (default)', () {
      const ConsoleInspector inspector = ConsoleInspector();
      final List<String> lines = _captureDebugPrint(() {
        inspector.onCreate(ObservableCreateEvent('Observable(x)', 1));
      });
      expect(lines, isEmpty);
    });

    test('onUpdate respects ObserverLogLevel filtering', () {
      ObserverConfig.logging = true;
      ObserverConfig.logLevel = ObserverLogLevel.lifecycle;
      const ConsoleInspector inspector = ConsoleInspector();
      final List<String> lines = _captureDebugPrint(() {
        inspector.onUpdate(ObservableUpdateEvent('Observable(x)', 1, 2));
      });
      expect(lines, isEmpty, reason: 'updates level is filtered out');
    });

    test('onDispose and onWarning print their expected content', () {
      ObserverConfig.logging = true;
      const ConsoleInspector inspector = ConsoleInspector();
      final List<String> disposeLines = _captureDebugPrint(() {
        inspector.onDispose(ObservableDisposeEvent('Observable(x)', 3));
      });
      expect(disposeLines.single, contains('descartado (3 listeners'));

      final List<String> warnLines = _captureDebugPrint(() {
        inspector.onWarning(
          WarningEvent('cuidado', suggestion: 'faça diferente'),
        );
      });
      expect(warnLines.single, contains('cuidado'));
      expect(warnLines.single, contains('faça diferente'));
    });

    test('onTrack and onEffectRun are no-ops (no console output)', () {
      ObserverConfig.logging = true;
      const ConsoleInspector inspector = ConsoleInspector();
      final List<String> lines = _captureDebugPrint(() {
        inspector.onTrack(TrackEvent('Observer(#1)', 'Observable(x)'));
        inspector.onEffectRun(EffectEvent('Effect(#1)'));
      });
      expect(lines, isEmpty);
    });
  });

  group('ObserverLogger + ConsoleInspector wiring', () {
    test(
      'registering an extra ObserverInspector does not duplicate, change, '
      'or silence the default console output',
      () {
        ObserverConfig.logging = true;
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.inspectors = <ObserverInspector>[recorder];

        final List<String> lines = _captureDebugPrint(() {
          ObserverLogger.created('Observable(x)', 1);
        });

        expect(lines, hasLength(1));
        expect(lines.single, contains('Observable(x) criado'));
        expect(recorder.events, hasLength(1));
        expect(recorder.events.single, isA<ObservableCreateEvent>());
      },
    );

    test(
      'dispatch: false skips the extra-inspector fan-out but console '
      'output still runs (e.g. Observable/Computed after CoreObservable '
      'already dispatched)',
      () {
        ObserverConfig.logging = true;
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.inspectors = <ObserverInspector>[recorder];

        final List<String> lines = _captureDebugPrint(() {
          ObserverLogger.created('Observable(x)', 1, dispatch: false);
        });

        expect(lines, hasLength(1));
        expect(lines.single, contains('Observable(x) criado'));
        expect(
          recorder.events,
          isEmpty,
          reason: 'dispatch: false must only skip ObserverConfig.inspectors',
        );
      },
    );
  });
}
