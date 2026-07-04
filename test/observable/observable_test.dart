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

    test('listen on an already-closed observable returns an inert '
        'subscription and does not register a listener', () {
      final Observable<int> obs = Observable<int>(0);
      obs.close();
      final subscription = obs.listen((int _) {});
      expect(subscription.isActive, isFalse);
    });

    test('listen with a when predicate only invokes the callback while '
        'the predicate holds', () {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      obs.listen(seen.add, when: (int v) => v.isEven);
      obs.value = 1; // odd: filtered out
      obs.value = 2; // even: passes
      obs.value = 3; // odd: filtered out
      obs.value = 4; // even: passes
      expect(seen, <int>[2, 4]);
    });

    test('a custom equals parameter controls whether a write notifies', () {
      final Observable<double> price = Observable<double>(
        1.0,
        equals: (double a, double b) => (a - b).abs() < 0.01,
      );
      int calls = 0;
      price.addListener(() => calls++);
      price.value = 1.005; // within tolerance: treated as unchanged
      expect(calls, 0);
      expect(price.value, 1.0);
      price.value = 1.5; // outside tolerance: notifies
      expect(calls, 1);
      expect(price.value, 1.5);
    });
  });

  group('Observable.batch', () {
    test('coalesces multiple writes into a single notification per '
        'observable', () {
      final Observable<String> firstName = Observable<String>('a');
      final Observable<String> lastName = Observable<String>('b');
      int firstNameCalls = 0;
      int lastNameCalls = 0;
      firstName.addListener(() => firstNameCalls++);
      lastName.addListener(() => lastNameCalls++);

      Observable.batch(() {
        firstName.value = 'Carlos';
        firstName.value = 'Carlos2';
        lastName.value = 'Castro';
      });

      expect(firstNameCalls, 1);
      expect(lastNameCalls, 1);
      expect(firstName.value, 'Carlos2');
      expect(lastName.value, 'Castro');
    });

    test('writes are applied immediately inside batch, only notification '
        'is deferred', () {
      final Observable<int> count = Observable<int>(0);
      final List<int> seenInsideBatch = <int>[];
      Observable.batch(() {
        count.value = 1;
        seenInsideBatch.add(count.value);
        count.value = 2;
        seenInsideBatch.add(count.value);
      });
      expect(seenInsideBatch, <int>[1, 2]);
    });

    test('nested batch calls only flush once, at the outermost level', () {
      final Observable<int> count = Observable<int>(0);
      int calls = 0;
      count.addListener(() => calls++);
      Observable.batch(() {
        Observable.batch(() {
          count.value = 1;
        });
        count.value = 2;
      });
      expect(calls, 1);
      expect(count.value, 2);
    });

    test('an exception thrown inside batch restores the depth counter and '
        'discards pending notifications, so a later batch works normally', () {
      final Observable<int> count = Observable<int>(0);
      int calls = 0;
      count.addListener(() => calls++);

      expect(
        () => Observable.batch(() {
          count.value = 1;
          throw StateError('boom');
        }),
        throwsStateError,
      );
      // Pending notification for the failed batch is discarded.
      expect(calls, 0);
      // The value write itself still applied (writes are not transactional).
      expect(count.value, 1);

      // A subsequent, successful batch works normally: proves the depth
      // counter was restored via `finally` rather than left corrupted.
      Observable.batch(() {
        count.value = 2;
      });
      expect(calls, 1);
      expect(count.value, 2);
    });
  });
}
