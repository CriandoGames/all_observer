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
  });
}
