import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/errors/observer_error.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/observable/collections/observable_list.dart';

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

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

    test('listen on an already-closed list returns an inert subscription '
        'and does not register a listener', () {
      final ObservableList<int> items = ObservableList<int>();
      items.close();
      final subscription = items.listen(() {});
      expect(subscription.isActive, isFalse);
    });

    test('close is idempotent: calling it twice does not throw', () {
      final ObservableList<int> items = ObservableList<int>();
      items.listen(() {});
      items.close();
      expect(items.close, returnsNormally);
      expect(items.isClosed, isTrue);
    });

    test('a mutation attempted after close is a silent no-op: the '
        'underlying data is unchanged and no exception is thrown', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2]);
      items.close();
      expect(() => items.add(3), returnsNormally);
      expect(items, <int>[1, 2]);
    });
  });

  group('ObservableList bulk operations notify exactly once', () {
    test('addAll(1000) notifies exactly once, not once per element', () {
      final ObservableList<int> items = ObservableList<int>();
      int calls = 0;
      items.listen(() => calls++);
      items.addAll(List<int>.generate(1000, (int i) => i));
      expect(calls, 1);
      expect(items.length, 1000);
    });

    test('removeWhere notifies exactly once when elements are removed', () {
      final ObservableList<int> items = ObservableList<int>(<int>[
        1,
        2,
        3,
        4,
        5,
        6,
      ]);
      int calls = 0;
      items.listen(() => calls++);
      items.removeWhere((int e) => e.isEven);
      expect(calls, 1);
      expect(items, <int>[1, 3, 5]);
    });

    test('removeWhere does not notify when nothing matches', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 3, 5]);
      int calls = 0;
      items.listen(() => calls++);
      items.removeWhere((int e) => e.isEven);
      expect(calls, 0);
    });

    test('retainWhere notifies exactly once', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2, 3, 4]);
      int calls = 0;
      items.listen(() => calls++);
      items.retainWhere((int e) => e.isEven);
      expect(calls, 1);
      expect(items, <int>[2, 4]);
    });

    test('insertAll notifies exactly once regardless of element count', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2]);
      int calls = 0;
      items.listen(() => calls++);
      items.insertAll(1, <int>[10, 20, 30]);
      expect(calls, 1);
      expect(items, <int>[1, 10, 20, 30, 2]);
    });

    test('clear on an already-empty list does not notify', () {
      final ObservableList<int> items = ObservableList<int>();
      int calls = 0;
      items.listen(() => calls++);
      items.clear();
      expect(calls, 0);
    });

    test('sort and shuffle each notify exactly once', () {
      final ObservableList<int> items = ObservableList<int>(<int>[3, 1, 2]);
      int calls = 0;
      items.listen(() => calls++);
      items.sort();
      expect(calls, 1);
      items.shuffle();
      expect(calls, 2);
    });
  });

  group('ObservableList write-during-build guard', () {
    test('strictMode turns a mutation during an active tracking context '
        'into a thrown ObserverError', () {
      ObserverConfig.strictMode = true;
      final ObservableList<int> items = ObservableList<int>();
      final TrackingContext ctx = TrackingContext(() {});
      expect(
        () => DependencyTracker.track(ctx, () => items.add(1)),
        throwsA(isA<ObserverError>()),
      );
    });

    test('mutation outside any tracking context is unaffected by '
        'strictMode', () {
      ObserverConfig.strictMode = true;
      final ObservableList<int> items = ObservableList<int>();
      expect(() => items.add(1), returnsNormally);
      expect(items, <int>[1]);
    });
  });

  group('ObservableList factory constructors', () {
    test('filled creates a list of the given length with every position '
        'set to fill', () {
      final ObservableList<int> items = ObservableList<int>.filled(3, 7);
      expect(items, <int>[7, 7, 7]);
    });

    test('empty creates an empty, growable list', () {
      final ObservableList<int> items = ObservableList<int>.empty(
        growable: true,
      );
      expect(items, isEmpty);
      expect(() => items.add(1), returnsNormally);
      expect(items, <int>[1]);
    });

    test('from copies elements out of a dynamic iterable', () {
      final ObservableList<int> items = ObservableList<int>.from(<int>[
        1,
        2,
        3,
      ]);
      expect(items, <int>[1, 2, 3]);
    });

    test('of copies elements out of a typed iterable', () {
      final ObservableList<int> items = ObservableList<int>.of(<int>[4, 5]);
      expect(items, <int>[4, 5]);
    });

    test('generate builds a list from an index-based generator', () {
      final ObservableList<int> items = ObservableList<int>.generate(
        4,
        (int i) => i * i,
      );
      expect(items, <int>[0, 1, 4, 9]);
    });

    test('unmodifiable creates a list that reads normally but throws on '
        'mutation', () {
      final ObservableList<int> items = ObservableList<int>.unmodifiable(<int>[
        1,
        2,
      ]);
      expect(items, <int>[1, 2]);
      expect(() => items.add(3), throwsUnsupportedError);
    });

    test('factories still notify listeners on later mutation', () {
      final ObservableList<int> items = ObservableList<int>.filled(
        2,
        0,
        growable: true,
      );
      int calls = 0;
      items.listen(() => calls++);
      items.add(1);
      expect(calls, 1);
    });
  });

  group('ObservableList convenience mutators', () {
    test('assign replaces every element and notifies exactly once', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2, 3]);
      int calls = 0;
      items.listen(() => calls++);
      items.assign(9);
      expect(calls, 1);
      expect(items, <int>[9]);
    });

    test('assignAll replaces every element and notifies exactly once', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2, 3]);
      int calls = 0;
      items.listen(() => calls++);
      items.assignAll(<int>[4, 5]);
      expect(calls, 1);
      expect(items, <int>[4, 5]);
    });

    test('assign on an already-closed list is a silent no-op', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2]);
      items.close();
      expect(() => items.assign(9), returnsNormally);
      expect(items, <int>[1, 2]);
    });

    test('addIf adds only when condition is true', () {
      final ObservableList<int> items = ObservableList<int>();
      items.addIf(true, 1);
      items.addIf(false, 2);
      expect(items, <int>[1]);
    });

    test('addAllIf adds only when condition is true', () {
      final ObservableList<int> items = ObservableList<int>();
      items.addAllIf(false, <int>[1, 2]);
      items.addAllIf(true, <int>[3, 4]);
      expect(items, <int>[3, 4]);
    });

    test('addIfNotNull skips null and adds non-null values', () {
      final ObservableList<int?> items = ObservableList<int?>();
      items.addIfNotNull(null);
      items.addIfNotNull(5);
      expect(items, <int?>[5]);
    });

    test('addIf with false condition does not notify listeners', () {
      final ObservableList<int> items = ObservableList<int>();
      int calls = 0;
      items.listen(() => calls++);
      items.addIf(false, 1);
      expect(calls, 0);
    });
  });
}
