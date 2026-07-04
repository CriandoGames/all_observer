import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/observable/observable.dart';

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('Observable', () {
    test('get/set updates the stored value', () {
      final Observable<int> obs = Observable<int>(0);
      expect(obs.value, 0);
      obs.value = 5;
      expect(obs.value, 5);
    });

    test('does not notify listeners when the assigned value is unchanged '
        '(first assignment included)', () {
      final Observable<int> obs = Observable<int>(0);
      int calls = 0;
      obs.addListener(() => calls++);
      obs.value = 0;
      expect(calls, 0);
    });

    test('notifies listeners only when the value actually differs', () {
      final Observable<int> obs = Observable<int>(0);
      int calls = 0;
      obs.addListener(() => calls++);
      obs.value = 1;
      obs.value = 1;
      obs.value = 2;
      expect(calls, 2);
    });

    test('does not override == / hashCode: comparisons stay explicit', () {
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(1);
      expect(a == b, isFalse);
      expect(a.value == b.value, isTrue);
    });

    test('refresh forces notification without changing the value', () {
      final Observable<List<int>> obs = Observable<List<int>>(<int>[1, 2]);
      int calls = 0;
      obs.addListener(() => calls++);
      obs.value.add(3);
      expect(calls, 0);
      obs.refresh();
      expect(calls, 1);
    });

    test('close removes listeners and ignores subsequent writes', () {
      final Observable<int> obs = Observable<int>(0);
      int calls = 0;
      obs.addListener(() => calls++);
      obs.close();
      expect(obs.isClosed, isTrue);
      obs.value = 1;
      expect(calls, 0);
      expect(obs.value, 0);
    });

    test('listen fires callback on change and cancel stops it', () {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      final sub = obs.listen(seen.add);
      obs.value = 1;
      sub.cancel();
      obs.value = 2;
      expect(seen, <int>[1]);
      expect(sub.isActive, isFalse);
    });

    test('listen with immediate=true fires once with the current value', () {
      final Observable<int> obs = Observable<int>(7);
      final List<int> seen = <int>[];
      obs.listen(seen.add, immediate: true);
      expect(seen, <int>[7]);
    });

    test('call() with an argument assigns; without one, returns the value', () {
      final Observable<int> obs = Observable<int>(0);
      expect(obs(), 0);
      obs(5);
      expect(obs(), 5);
    });

    test('reading value registers a dependency in the active tracking '
        'context', () {
      final Observable<int> obs = Observable<int>(0);
      int calls = 0;
      final TrackingContext ctx = TrackingContext(() => calls++);
      DependencyTracker.track(ctx, () => obs.value);
      obs.value = 1;
      expect(calls, 1);
    });
  });
}
