import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/errors/observer_error.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/observable/collections/observable_map.dart';

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

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

  group('ObservableMap write-during-build guard', () {
    test('strictMode turns a mutation during an active tracking context '
        'into a thrown ObserverError', () {
      ObserverConfig.strictMode = true;
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      final TrackingContext ctx = TrackingContext(() {});
      expect(
        () => DependencyTracker.track(ctx, () => map['a'] = 1),
        throwsA(isA<ObserverError>()),
      );
    });

    test('mutation outside any tracking context is unaffected by '
        'strictMode', () {
      ObserverConfig.strictMode = true;
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      expect(() => map['a'] = 1, returnsNormally);
      expect(map['a'], 1);
    });
  });

  group('ObservableMap close', () {
    test('close stops further notifications', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      int calls = 0;
      map.listen(() => calls++);
      map.close();
      map['a'] = 1;
      expect(calls, 0);
    });

    test('listen on an already-closed map returns an inert subscription '
        'and does not register a listener', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      map.close();
      final subscription = map.listen(() {});
      expect(subscription.isActive, isFalse);
    });

    test('close is idempotent: calling it twice does not throw', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>();
      map.listen(() {});
      map.close();
      expect(map.close, returnsNormally);
      expect(map.isClosed, isTrue);
    });

    test('a mutation attempted after close is a silent no-op: the '
        'underlying data is unchanged and no exception is thrown', () {
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1},
      );
      map.close();
      expect(() => map['b'] = 2, returnsNormally);
      expect(() => map.remove('a'), returnsNormally);
      expect(map, <String, int>{'a': 1});
    });
  });
}
