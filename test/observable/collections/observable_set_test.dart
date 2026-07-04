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
  });
}
