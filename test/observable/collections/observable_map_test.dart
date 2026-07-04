import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/observable/collections/observable_map.dart';

void main() {
  group('ObservableMap', () {
    test('reading a key registers a dependency', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1},
      );
      int calls = 0;
      final TrackingContext ctx = TrackingContext(() => calls++);
      DependencyTracker.track(ctx, () => map['a']);
      map['a'] = 2;
      expect(calls, 1);
    });

    test('[]=, remove, clear notify listeners', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      int calls = 0;
      map.listen(() => calls++);
      map['a'] = 1;
      map.remove('a');
      map['b'] = 2;
      map.clear();
      expect(calls, 4);
    });

    test('removing a missing key does not notify', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      int calls = 0;
      map.listen(() => calls++);
      map.remove('missing');
      expect(calls, 0);
    });

    test('assigning the identical value to an existing key does not '
        'notify', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1},
      );
      int calls = 0;
      map.listen(() => calls++);
      map['a'] = 1;
      expect(calls, 0);
    });

    test('clear on an already-empty map does not notify', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      int calls = 0;
      map.listen(() => calls++);
      map.clear();
      expect(calls, 0);
    });

    test('addAll notifies exactly once regardless of entry count', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      int calls = 0;
      map.listen(() => calls++);
      map.addAll(<String, int>{'a': 1, 'b': 2, 'c': 3});
      expect(calls, 1);
      expect(map.length, 3);
    });

    test('addAll with an empty map does not notify', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1},
      );
      int calls = 0;
      map.listen(() => calls++);
      map.addAll(<String, int>{});
      expect(calls, 0);
    });

    test('removeWhere notifies exactly once when entries are removed', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1, 'b': 2, 'c': 3, 'd': 4},
      );
      int calls = 0;
      map.listen(() => calls++);
      map.removeWhere((String k, int v) => v.isEven);
      expect(calls, 1);
      expect(map.keys, <String>['a', 'c']);
    });

    test('removeWhere does not notify when nothing matches', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1, 'c': 3},
      );
      int calls = 0;
      map.listen(() => calls++);
      map.removeWhere((String k, int v) => v.isEven);
      expect(calls, 0);
    });
  });
}
