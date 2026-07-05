import 'package:all_observer/src/core/typedefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

void main() {
  group('untracked()', () {
    test('reads a value without subscribing the current tracker', () {
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(10);
      int runs = 0;
      final Disposer dispose = effect(() {
        runs++;
        a.value; // tracked dependency
        untracked(() => b.value); // read but not tracked
      });
      expect(runs, 1);
      expect(a.hasListeners, isTrue);
      expect(
        b.hasListeners,
        isFalse,
        reason: 'untracked reads must not register a dependency',
      );

      b.value = 20;
      expect(runs, 1, reason: 'b is not a dependency, so no re-run');

      a.value = 2;
      expect(runs, 2);
      dispose();
    });

    test('returns the result of action', () {
      final Observable<int> a = Observable<int>(42);
      expect(untracked(() => a.value * 2), 84);
    });

    test('supports nesting', () {
      final Observable<int> a = Observable<int>(1);
      final int result = untracked(() => untracked(() => a.value + 1));
      expect(result, 2);
    });
  });

  group('Observable.peek()', () {
    test('reads the current value without tracking', () {
      final Observable<int> count = Observable<int>(5);
      int runs = 0;
      final Disposer dispose = effect(() {
        runs++;
        count.peek();
      });
      expect(runs, 1);
      expect(count.hasListeners, isFalse);

      count.value = 6;
      expect(runs, 1, reason: 'peek() must not create a dependency');
      expect(count.peek(), 6);
      dispose();
    });
  });

  group('Observable.previousValue', () {
    test('is null before the first change', () {
      final Observable<int> count = Observable<int>(1);
      expect(count.previousValue, isNull);
    });

    test('holds the value immediately before the last notified change', () {
      final Observable<int> count = Observable<int>(1);
      count.value = 2;
      expect(count.previousValue, 1);
      count.value = 3;
      expect(count.previousValue, 2);
    });

    test('a no-op write (same value) does not update previousValue', () {
      final Observable<int> count = Observable<int>(1);
      count.value = 2;
      count.value = 2; // no-op, equal to current value
      expect(count.previousValue, 1);
    });

    test('refresh() does not change previousValue', () {
      final Observable<int> count = Observable<int>(1);
      count.value = 2;
      count.refresh();
      expect(count.previousValue, 1);
    });
  });
}
