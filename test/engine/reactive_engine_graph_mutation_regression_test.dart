import 'package:all_observer/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/mini_preset.dart';

void main() {
  setUp(resetMiniPreset);

  group('ReactiveEngine graph mutation regressions', () {
    test('disposing an effect during computed dirty checking is safe', () {
      final MiniSignal<bool> shouldDispose = MiniSignal<bool>(false);
      late final MiniEffect stop;

      final MiniComputed<int> inner = MiniComputed<int>(() {
        if (shouldDispose.get()) {
          stop.stop();
        }
        return 0;
      });
      final MiniComputed<int> outer = MiniComputed<int>(() => inner.get());

      stop = effect(() {
        outer.get();
      });

      shouldDispose.set(true);

      expect(stop.deps, isNull);
      expect(stop.flags.hasAny(ReactiveFlags.watching), isFalse);
      shouldDispose.set(false);
      expect(stop.runs, 1);
      expectConsistentGraph(<ReactiveNode>[shouldDispose, inner, outer, stop]);
    });

    test('effect disposed during another subscriber update stays detached', () {
      final MiniSignal<int> source = MiniSignal<int>(0);
      late final MiniEffect stopFirst;
      int firstRuns = 0;
      int secondValue = -1;
      int thirdValue = -1;

      final MiniComputed<int> derived = MiniComputed<int>(() {
        final int value = source.get();
        if (value == 1) {
          stopFirst.stop();
        }
        return value;
      });

      stopFirst = effect(() {
        derived.get();
        firstRuns++;
      });
      final MiniEffect second = effect(() {
        secondValue = derived.get();
      });
      final MiniEffect third = effect(() {
        thirdValue = derived.get();
      });

      expect(firstRuns, 1);
      expect(secondValue, 0);
      expect(thirdValue, 0);

      source.set(1);

      expect(firstRuns, 1);
      expect(secondValue, 1);
      expect(thirdValue, 1);
      expect(stopFirst.deps, isNull);
      expect(stopFirst.flags.hasAny(ReactiveFlags.watching), isFalse);
      expectConsistentGraph(<ReactiveNode>[
        source,
        derived,
        stopFirst,
        second,
        third,
      ]);

      source.set(2);

      expect(firstRuns, 1);
      expect(secondValue, 2);
      expect(thirdValue, 2);
      expectConsistentGraph(<ReactiveNode>[
        source,
        derived,
        stopFirst,
        second,
        third,
      ]);
    });

    test('dirty checking handles a dependency that loses subscribers', () {
      final MiniSignal<int> source = MiniSignal<int>(0);
      late final MiniEffect stop;

      final MiniComputed<int> stable = MiniComputed<int>(() {
        source.get();
        return 0;
      });
      final MiniComputed<int> disposing = MiniComputed<int>(() {
        final int value = source.get();
        if (value != 0) {
          stop.stop();
        }
        return value;
      });
      final MiniComputed<int> combined = MiniComputed<int>(() {
        stable.get();
        disposing.get();
        return 0;
      });

      stop = effect(() {
        combined.get();
      });

      source.set(1);

      expect(stop.deps, isNull);
      expect(stop.flags.hasAny(ReactiveFlags.watching), isFalse);
      expectConsistentGraph(<ReactiveNode>[
        source,
        stable,
        disposing,
        combined,
        stop,
      ]);
    });

    test(
      'reverted value inside a batch does not notify downstream effects',
      () {
        final MiniSignal<int> source = MiniSignal<int>(0);
        final MiniComputed<int> derived = MiniComputed<int>(() => source.get());
        final MiniEffect subscriber = effect(() {
          derived.get();
        });

        expect(derived.recomputes, 1);
        expect(subscriber.runs, 1);

        startBatch();
        source.set(1);
        source.set(0);
        endBatch();

        expect(derived.recomputes, 1);
        expect(subscriber.runs, 1);
        expectConsistentGraph(<ReactiveNode>[source, derived, subscriber]);
      },
    );
  });
}
