import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/errors/observer_error.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/observable/collections/observable_set.dart';

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('ObservableSet', () {
    test('reading contains registers a dependency', () {
      final ObservableSet<int> set = ObservableSet<int>(<int>{1});
      int calls = 0;
      final TrackingContext ctx = TrackingContext(() => calls++);
      DependencyTracker.track(ctx, () => set.contains(1));
      set.add(2);
      expect(calls, 1);
    });

    test('add/remove/clear notify listeners', () {
      final ObservableSet<int> set = ObservableSet<int>();
      int calls = 0;
      set.listen(() => calls++);
      set.add(1);
      set.remove(1);
      set.add(2);
      set.clear();
      expect(calls, 4);
    });

    test('adding a duplicate element does not notify', () {
      final ObservableSet<int> set = ObservableSet<int>(<int>{1});
      int calls = 0;
      set.listen(() => calls++);
      set.add(1);
      expect(calls, 0);
    });

    test('clear on an already-empty set does not notify', () {
      final ObservableSet<int> set = ObservableSet<int>();
      int calls = 0;
      set.listen(() => calls++);
      set.clear();
      expect(calls, 0);
    });

    test('addAll notifies exactly once regardless of element count', () {
      final ObservableSet<int> set = ObservableSet<int>();
      int calls = 0;
      set.listen(() => calls++);
      set.addAll(<int>[1, 2, 3, 4, 5]);
      expect(calls, 1);
      expect(set.length, 5);
    });

    test('addAll with only already-present elements does not notify', () {
      final ObservableSet<int> set = ObservableSet<int>(<int>{1, 2});
      int calls = 0;
      set.listen(() => calls++);
      set.addAll(<int>[1, 2]);
      expect(calls, 0);
    });

    test('removeWhere notifies exactly once when elements are removed', () {
      final ObservableSet<int> set = ObservableSet<int>(<int>{1, 2, 3, 4});
      int calls = 0;
      set.listen(() => calls++);
      set.removeWhere((int e) => e.isEven);
      expect(calls, 1);
      expect(set, <int>{1, 3});
    });

    test('retainWhere notifies exactly once', () {
      final ObservableSet<int> set = ObservableSet<int>(<int>{1, 2, 3, 4});
      int calls = 0;
      set.listen(() => calls++);
      set.retainWhere((int e) => e.isEven);
      expect(calls, 1);
      expect(set, <int>{2, 4});
    });

    test('listen on an already-closed set returns an inert subscription', () {
      final ObservableSet<int> set = ObservableSet<int>();
      set.close();
      final subscription = set.listen(() {});
      expect(subscription.isActive, isFalse);
    });
  });

  group('ObservableSet write-during-build guard', () {
    test('strictMode turns a mutation during an active tracking context '
        'into a thrown ObserverError', () {
      ObserverConfig.strictMode = true;
      final ObservableSet<int> set = ObservableSet<int>();
      final TrackingContext ctx = TrackingContext(() {});
      expect(
        () => DependencyTracker.track(ctx, () => set.add(1)),
        throwsA(isA<ObserverError>()),
      );
    });

    test('mutation outside any tracking context is unaffected by '
        'strictMode', () {
      ObserverConfig.strictMode = true;
      final ObservableSet<int> set = ObservableSet<int>();
      expect(() => set.add(1), returnsNormally);
      expect(set, <int>{1});
    });
  });

  group('ObservableSet close', () {
    test('close stops further notifications', () {
      final ObservableSet<int> set = ObservableSet<int>();
      int calls = 0;
      set.listen(() => calls++);
      set.close();
      set.add(1);
      expect(calls, 0);
    });

    test('close is idempotent: calling it twice does not throw', () {
      final ObservableSet<int> set = ObservableSet<int>();
      set.listen(() {});
      set.close();
      expect(set.close, returnsNormally);
      expect(set.isClosed, isTrue);
    });

    test('a mutation attempted after close is a silent no-op: the '
        'underlying data is unchanged and no exception is thrown', () {
      final ObservableSet<int> set = ObservableSet<int>(<int>{1, 2});
      set.close();
      expect(() => set.add(3), returnsNormally);
      expect(() => set.remove(1), returnsNormally);
      expect(set, <int>{1, 2});
    });
  });
}
