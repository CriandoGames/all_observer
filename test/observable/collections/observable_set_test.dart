import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/observable/collections/observable_set.dart';

void main() {
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
}
