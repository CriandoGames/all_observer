import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/workers/workers.dart';

void main() {
  group('ever', () {
    test('runs the callback on every change', () {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      final Worker worker = ever(obs, seen.add);
      obs.value = 1;
      obs.value = 2;
      worker.dispose();
      obs.value = 3;
      expect(seen, <int>[1, 2]);
      expect(worker.isDisposed, isTrue);
    });
  });

  group('once', () {
    test('runs the callback only on the first change', () {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      once(obs, seen.add);
      obs.value = 1;
      obs.value = 2;
      expect(seen, <int>[1]);
    });
  });

  group('debounce', () {
    testWidgets('runs the callback once after the value stops changing', (
      tester,
    ) async {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      debounce(obs, seen.add, time: const Duration(milliseconds: 200));

      obs.value = 1;
      await tester.pump(const Duration(milliseconds: 50));
      obs.value = 2;
      await tester.pump(const Duration(milliseconds: 50));
      obs.value = 3;
      expect(seen, isEmpty);

      await tester.pump(const Duration(milliseconds: 250));
      expect(seen, <int>[3]);
    });

    testWidgets('dispose cancels the pending callback', (tester) async {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      final Worker worker = debounce(
        obs,
        seen.add,
        time: const Duration(milliseconds: 100),
      );
      obs.value = 1;
      worker.dispose();
      await tester.pump(const Duration(milliseconds: 200));
      expect(seen, isEmpty);
    });
  });

  group('interval', () {
    testWidgets('runs at most once per interval while values keep '
        'changing', (tester) async {
      final Observable<int> obs = Observable<int>(0);
      final List<int> seen = <int>[];
      interval(obs, seen.add, time: const Duration(milliseconds: 100));

      obs.value = 1; // fires immediately
      await tester.pump(const Duration(milliseconds: 10));
      obs.value = 2; // queued during cooldown
      obs.value = 3; // overwrites queued value
      await tester.pump(const Duration(milliseconds: 150));

      expect(seen, <int>[1, 3]);
    });
  });

  group('Workers', () {
    test('dispose stops every wrapped worker', () {
      final Observable<int> a = Observable<int>(0);
      final Observable<int> b = Observable<int>(0);
      final List<int> seen = <int>[];
      final Workers group = Workers(<Worker>[
        ever(a, seen.add),
        ever(b, seen.add),
      ]);
      group.dispose();
      a.value = 1;
      b.value = 1;
      expect(seen, isEmpty);
    });
  });
}
