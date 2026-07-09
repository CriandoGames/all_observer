import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _AuditInspector extends ObserverInspector {
  final List<ObservableEvent> events = <ObservableEvent>[];

  @override
  void onCreate(ObservableCreateEvent event) => events.add(event);

  @override
  void onUpdate(ObservableUpdateEvent event) => events.add(event);

  @override
  void onDispose(ObservableDisposeEvent event) => events.add(event);

  @override
  void onWarning(WarningEvent event) => events.add(event);
}

final class _ThrowingUpdateInspector extends ObserverInspector {
  @override
  void onUpdate(ObservableUpdateEvent event) {
    throw StateError('external logger failed');
  }
}

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('custom ObserverInspector public contract', () {
    test('receives create, update and dispose events with typed payloads', () {
      final _AuditInspector inspector = _AuditInspector();
      ObserverConfig.inspectors.add(inspector);

      final Observable<int> count = Observable<int>(0, name: 'count');
      count.value = 1;
      count.close();

      final ObservableCreateEvent create = inspector.events
          .whereType<ObservableCreateEvent>()
          .single;
      final ObservableUpdateEvent update = inspector.events
          .whereType<ObservableUpdateEvent>()
          .single;
      final ObservableDisposeEvent dispose = inspector.events
          .whereType<ObservableDisposeEvent>()
          .single;

      expect(create.label, contains('count'));
      expect(create.initialValue, 0);
      expect(update.label, contains('count'));
      expect(update.oldValue, 0);
      expect(update.newValue, 1);
      expect(dispose.label, contains('count'));
    });

    test('receives warnings independently from built-in console logging', () {
      final _AuditInspector inspector = _AuditInspector();
      ObserverConfig.warnings = false;
      ObserverConfig.listenerLeakThreshold = 1;
      ObserverConfig.inspectors.add(inspector);
      final Observable<int> count = Observable<int>(0, name: 'count');

      count.listen((int _) {});

      final WarningEvent warning = inspector.events
          .whereType<WarningEvent>()
          .single;
      expect(warning.label, contains('Possível vazamento'));
      expect(warning.suggestion, isNotNull);
      count.close();
    });

    test('notifies every registered inspector', () {
      final _AuditInspector first = _AuditInspector();
      final _AuditInspector second = _AuditInspector();
      ObserverConfig.inspectors.addAll(<ObserverInspector>[first, second]);

      final Observable<int> count = Observable<int>(0);
      count.value = 1;

      expect(first.events.whereType<ObservableUpdateEvent>(), hasLength(1));
      expect(second.events.whereType<ObservableUpdateEvent>(), hasLength(1));
      count.close();
    });

    test(
      'a throwing inspector neither blocks later inspectors nor the update',
      () {
        final _AuditInspector audit = _AuditInspector();
        ObserverConfig.inspectors.addAll(<ObserverInspector>[
          _ThrowingUpdateInspector(),
          audit,
        ]);
        final Observable<int> count = Observable<int>(0);
        int listenerCalls = 0;
        count.listen((int _) => listenerCalls++);

        expect(() => count.value = 1, returnsNormally);

        expect(count.value, 1);
        expect(listenerCalls, 1);
        expect(audit.events.whereType<ObservableUpdateEvent>(), hasLength(1));
        count.close();
      },
    );

    test('optionally captures stack traces for external audit logging', () {
      ObserverConfig.captureStackTraces = true;
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors.add(recorder);

      final Observable<int> count = Observable<int>(0);
      count.value = 1;

      expect(
        recorder.events.whereType<ObservableUpdateEvent>().single.stackTrace,
        isNotNull,
      );
      count.close();
    });
  });
}
