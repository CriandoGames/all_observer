import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/computed.dart';
import 'package:all_observer/src/observable/observable.dart';

void main() {
  group('Computed', () {
    test('is lazy: compute does not run before the first read', () {
      final Observable<int> source = Observable<int>(1);
      int computeRuns = 0;
      final Computed<int> derived = Computed<int>(() {
        computeRuns++;
        return source.value * 2;
      });
      expect(computeRuns, 0);
      expect(derived.value, 2);
      expect(computeRuns, 1);
    });

    test('memoizes: repeated reads without a dependency change do not '
        'recompute', () {
      final Observable<int> source = Observable<int>(1);
      int computeRuns = 0;
      final Computed<int> derived = Computed<int>(() {
        computeRuns++;
        return source.value * 2;
      });
      derived.value;
      derived.value;
      derived.value;
      expect(computeRuns, 1);
    });

    test('recomputes when a dependency changes', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> derived = Computed<int>(() => source.value * 2);
      expect(derived.value, 2);
      source.value = 5;
      expect(derived.value, 10);
    });

    test('only notifies its own listeners when the recomputed value '
        'actually differs', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<bool> isEven = Computed<bool>(() => source.value.isEven);
      // Force the first compute so a dependency is registered.
      expect(isEven.value, isFalse);
      int calls = 0;
      isEven.addListener(() => calls++);

      source.value = 3; // still odd: derived value unchanged
      expect(isEven.value, isFalse);
      expect(calls, 0);

      source.value = 4; // now even: derived value changes
      expect(isEven.value, isTrue);
      expect(calls, 1);
    });

    test('supports dynamic/conditional dependencies (an if inside compute)',
        () {
      final Observable<bool> useA = Observable<bool>(true);
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(2);
      final Computed<int> derived = Computed<int>(
        () => useA.value ? a.value : b.value,
      );
      expect(derived.value, 1);

      // Switch dependency from a to b.
      useA.value = false;
      expect(derived.value, 2);

      // Changing `a` no longer affects the derived value.
      int calls = 0;
      derived.addListener(() => calls++);
      a.value = 99;
      expect(derived.value, 2);
      expect(calls, 0);

      // But changing `b` does.
      b.value = 42;
      expect(derived.value, 42);
      expect(calls, 1);
    });

    test('close unsubscribes from all current dependencies', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> derived = Computed<int>(() => source.value * 2);
      expect(derived.value, 2); // forces compute + subscribes to `source`
      expect(source.hasListeners, isTrue);
      derived.close();
      expect(source.hasListeners, isFalse);
      expect(derived.isClosed, isTrue);
    });

    test('reading value inside a tracking context registers a dependency '
        'on the Computed itself, like a plain Observable', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> derived = Computed<int>(() => source.value * 2);
      int calls = 0;
      derived.listen((int _) => calls++);
      source.value = 2;
      expect(calls, 1);
      expect(derived.value, 4);
    });
  });
}
