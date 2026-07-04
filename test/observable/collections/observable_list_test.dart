import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/observable/collections/observable_list.dart';

void main() {
  group('ObservableList', () {
    test('reading length registers a dependency', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2]);
      int calls = 0;
      final TrackingContext ctx = TrackingContext(() => calls++);
      DependencyTracker.track(ctx, () => items.length);
      items.add(3);
      expect(calls, 1);
    });

    test('add/remove/clear notify listeners', () {
      final ObservableList<int> items = ObservableList<int>();
      int calls = 0;
      items.listen(() => calls++);
      items.add(1);
      items.addAll(<int>[2, 3]);
      items.remove(2);
      items.clear();
      expect(calls, 4);
    });

    test('operator [] reads and []= writes correctly', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2, 3]);
      expect(items[1], 2);
      items[1] = 20;
      expect(items[1], 20);
    });

    test('close stops further notifications', () {
      final ObservableList<int> items = ObservableList<int>();
      int calls = 0;
      items.listen(() => calls++);
      items.close();
      items.add(1);
      expect(calls, 0);
    });
  });
}
