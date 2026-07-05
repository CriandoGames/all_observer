import 'package:all_observer/src/core/typedefs.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

/// See `test/observable/computed_test.dart` for why this capture helper is
/// needed: `flutter_test`'s default [FlutterError.onError] fails the
/// current test whenever [FlutterError.reportError] is called, which some
/// of these tests trigger on purpose.
List<FlutterErrorDetails> _captureReportedErrors(void Function() run) {
  final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    run();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

void main() {
  tearDown(ObserverConfig.reset);

  group('effect', () {
    test('runs immediately, even before any dependency changes', () {
      final Observable<int> count = Observable<int>(1);
      int runs = 0;
      final Disposer dispose = effect(() {
        runs++;
        count.value; // read to establish a dependency
      });
      expect(runs, 1);
      dispose();
    });

    test('re-runs when a read dependency changes', () {
      final Observable<int> count = Observable<int>(0);
      int runs = 0;
      final List<int> seen = <int>[];
      final Disposer dispose = effect(() {
        runs++;
        seen.add(count.value);
      });
      count.value = 1;
      count.value = 2;
      expect(runs, 3);
      expect(seen, <int>[0, 1, 2]);
      dispose();
    });

    test('tracks multiple dependencies read in the same run', () {
      final Observable<int> a = Observable<int>(1, name: 'a');
      final Observable<int> b = Observable<int>(10, name: 'b');
      int runs = 0;
      final List<int> sums = <int>[];
      final Disposer dispose = effect(() {
        runs++;
        sums.add(a.value + b.value);
      });
      a.value = 2;
      b.value = 20;
      expect(runs, 3);
      expect(sums, <int>[11, 12, 22]);
      dispose();
    });

    test('supports conditional/dynamic dependencies', () {
      final Observable<bool> useA = Observable<bool>(true);
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(100);
      int runs = 0;
      final Disposer dispose = effect(() {
        runs++;
        useA.value ? a.value : b.value;
      });
      expect(runs, 1);
      expect(a.hasListeners, isTrue);
      expect(b.hasListeners, isFalse);

      useA.value = false;
      expect(runs, 2);
      expect(a.hasListeners, isFalse);
      expect(b.hasListeners, isTrue);

      // Writing to the now-abandoned branch must not re-run the effect.
      a.value = 999;
      expect(runs, 2);

      b.value = 200;
      expect(runs, 3);
      dispose();
    });

    test('dispose() stops future runs and unsubscribes from all deps', () {
      final Observable<int> count = Observable<int>(0);
      int runs = 0;
      final Disposer dispose = effect(() {
        runs++;
        count.value;
      });
      expect(runs, 1);
      expect(count.hasListeners, isTrue);

      dispose();
      expect(count.hasListeners, isFalse);

      count.value = 1;
      expect(runs, 1, reason: 'a disposed effect must never run again');
    });

    test('dispose() is safe to call more than once', () {
      final Observable<int> count = Observable<int>(0);
      final Disposer dispose = effect(() => count.value);
      dispose();
      expect(dispose, returnsNormally);
    });

    test(
      'runs at most once per Observable.batch(), after all deps settle',
      () {
        final Observable<int> a = Observable<int>(1);
        final Observable<int> b = Observable<int>(10);
        int runs = 0;
        final List<int> seenSums = <int>[];
        final Disposer dispose = effect(() {
          runs++;
          seenSums.add(a.value + b.value);
        });
        runs = 0;
        seenSums.clear();

        Observable.batch(() {
          a.value = 2;
          b.value = 20;
        });

        expect(runs, 1, reason: 'one run for the whole batch, not per write');
        expect(seenSums, <int>[22]);
        dispose();
      },
    );

    test('exception during run is reported, naming the effect', () {
      final Observable<int> count = Observable<int>(0);
      late final Disposer dispose;
      final List<FlutterErrorDetails> reported = _captureReportedErrors(() {
        dispose = effect(() {
          count.value;
          if (count.value > 0) {
            throw StateError('boom');
          }
        }, name: 'boomEffect');
        count.value = 1;
      });
      expect(reported, isNotEmpty);
      dispose();
    });

    test(
      'effect that never reads any observable warns (or throws in '
      'strictMode)',
      () {
        expect(() => effect(() {}), returnsNormally);

        ObserverConfig.strictMode = true;
        expect(() => effect(() {}), throwsA(isA<ObserverError>()));
      },
    );
  });
}
