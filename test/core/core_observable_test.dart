import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/core.dart';

/// `CoreObservable` is the pure-Dart engine `Observable` wraps (see
/// `lib/src/core/core_observable.dart`'s doc). These tests exercise it
/// directly, importing only `package:all_observer/core.dart` — proving it
/// is usable without the main Flutter-facing barrel.
void main() {
  tearDown(ObserverConfig.reset);

  group('CoreObservable', () {
    test('holds the initial value and notifies on change', () {
      final CoreObservable<int> count = CoreObservable<int>(1);
      expect(count.value, 1);

      int notifications = 0;
      count.addListener(() => notifications++);
      count.value = 2;
      expect(count.value, 2);
      expect(notifications, 1);
    });

    test('does not notify when the new value equals the current one', () {
      final CoreObservable<int> count = CoreObservable<int>(1);
      int notifications = 0;
      count.addListener(() => notifications++);
      count.value = 1;
      expect(notifications, 0);
    });

    test('custom equals overrides the default == comparison', () {
      final CoreObservable<double> temp = CoreObservable<double>(
        20.0,
        equals: (double a, double b) => (a - b).abs() < 0.5,
      );
      int notifications = 0;
      temp.addListener(() => notifications++);
      temp.value = 20.3; // within tolerance
      expect(notifications, 0);
      temp.value = 21.0; // outside tolerance
      expect(notifications, 1);
    });

    test('peek() reads without tracking', () {
      final CoreObservable<int> count = CoreObservable<int>(5);
      int runs = 0;
      count.addListener(() => runs++);
      expect(count.peek(), 5);
      count.value = 6;
      expect(runs, 1);
    });

    test('previousValue is null before the first change, then tracks it', () {
      final CoreObservable<int> count = CoreObservable<int>(1);
      expect(count.previousValue, isNull);
      count.value = 2;
      expect(count.previousValue, 1);
      count.value = 3;
      expect(count.previousValue, 2);
    });

    test('refresh() notifies without changing value or previousValue', () {
      final CoreObservable<int> count = CoreObservable<int>(1);
      int notifications = 0;
      count.addListener(() => notifications++);
      count.refresh();
      expect(notifications, 1);
      expect(count.value, 1);
      expect(count.previousValue, isNull);
    });

    test('listen() supports immediate and when', () {
      final CoreObservable<int> count = CoreObservable<int>(1);
      final List<int> seen = <int>[];
      count.listen(seen.add, immediate: true, when: (int v) => v.isEven);
      expect(seen, isEmpty); // 1 is odd, immediate call is filtered by when
      count.value = 2;
      expect(seen, <int>[2]);
      count.value = 3;
      expect(seen, <int>[2]); // odd, filtered
    });

    test('close() removes listeners and stops future writes', () {
      final CoreObservable<int> count = CoreObservable<int>(1);
      int notifications = 0;
      count.addListener(() => notifications++);
      count.close();
      expect(count.isClosed, isTrue);
      expect(count.hasListeners, isFalse);

      count.value = 2;
      expect(notifications, 0);
      expect(count.value, 1, reason: 'write after close is a no-op');
    });

    test('strictMode throws ObserverError on write-during-tracking', () {
      ObserverConfig.strictMode = true;
      final CoreObservable<int> count = CoreObservable<int>(1);
      final TrackingContext ctx = TrackingContext(() {});
      expect(
        () => DependencyTracker.track(ctx, () {
          count.value = 2;
        }),
        throwsA(isA<ObserverError>()),
      );
    });

    test(
      'dispatches onCreate/onUpdate/onDispose to ObserverConfig.inspectors',
      () {
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.inspectors = <ObserverInspector>[recorder];

        final CoreObservable<int> count = CoreObservable<int>(1, name: 'count');
        count.value = 2;
        count.close();

        expect(
          recorder.events.whereType<ObservableCreateEvent>(),
          hasLength(1),
        );
        expect(
          recorder.events.whereType<ObservableUpdateEvent>(),
          hasLength(1),
        );
        expect(
          recorder.events.whereType<ObservableDisposeEvent>(),
          hasLength(1),
        );
      },
    );

    test('writing the same observable twice inside a batch notifies once', () {
      final CoreObservable<int> a = CoreObservable<int>(1);
      int notifications = 0;
      a.addListener(() => notifications++);

      BatchScope.run(() {
        a.value = 2;
        a.value = 3;
      });

      expect(notifications, 1);
      expect(a.value, 3);
    });

    test('a bare write outside any explicit batch still notifies exactly '
        'once (auto micro-batch)', () {
      final CoreObservable<int> a = CoreObservable<int>(1);
      int notifications = 0;
      a.addListener(() => notifications++);

      a.value = 2;

      expect(notifications, 1);
    });
  });
}
