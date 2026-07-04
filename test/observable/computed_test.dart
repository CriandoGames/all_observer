import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/computed.dart';
import 'package:all_observer/src/observable/observable.dart';

bool _closeEnough(double a, double b) => (a - b).abs() < 0.01;

/// Temporarily replaces [FlutterError.onError] with a capturing handler for
/// the duration of [run], restoring the previous handler afterwards (even
/// if [run] throws). See the identical helper in
/// `test/core/listener_registry_test.dart` for why this is needed:
/// `flutter_test`'s default [FlutterError.onError] fails the current test
/// whenever [FlutterError.reportError] is called, which these tests trigger
/// on purpose as part of the behavior under test.
///
/// Substitui temporariamente [FlutterError.onError] por um handler que
/// captura os erros durante [run], restaurando o handler anterior depois
/// (mesmo que [run] lance). Ver o helper idêntico em
/// `test/core/listener_registry_test.dart` para o motivo: o
/// [FlutterError.onError] padrão do `flutter_test` falha o teste atual
/// sempre que [FlutterError.reportError] é chamado, o que estes testes
/// disparam de propósito.
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

    test(
      'supports dynamic/conditional dependencies (an if inside compute)',
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
      },
    );

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

  group('Computed custom equals', () {
    test('a tolerance-based equals suppresses notification when the '
        'recomputed value is "close enough" to the previous one', () {
      final Observable<double> celsius = Observable<double>(20.0);
      final Computed<double> fahrenheit = Computed<double>(
        () => celsius.value * 9 / 5 + 32,
        equals: _closeEnough,
      );
      expect(fahrenheit.value, closeTo(68.0, 0.001));

      int calls = 0;
      fahrenheit.addListener(() => calls++);

      // A tiny change in celsius produces a tiny change in fahrenheit,
      // within tolerance: no notification, even though the recomputed
      // double is technically != the cached one.
      celsius.value = 20.001;
      expect(calls, 0);

      // A large enough change crosses the tolerance and does notify.
      celsius.value = 25.0;
      expect(calls, 1);
      expect(fahrenheit.value, closeTo(77.0, 0.001));
    });
  });

  group('Computed diamond glitch mitigation (batch)', () {
    test('inside Observable.batch, a diamond dependency graph recomputes '
        'the bottom Computed exactly once and never observes mixed state', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> doubled = Computed<int>(() => source.value * 2);
      final Computed<int> tripled = Computed<int>(() => source.value * 3);
      final List<int> seenSums = <int>[];
      final Computed<int> sum = Computed<int>(() {
        final int value = doubled.value + tripled.value;
        seenSums.add(value);
        return value;
      });

      // Force all three live before the batch so listeners are attached.
      expect(sum.value, 5); // 2 + 3
      seenSums.clear();

      int sumNotifications = 0;
      sum.addListener(() => sumNotifications++);

      Observable.batch(() {
        source.value = 10;
      });

      // Exactly one recompute of `sum` after the batch, with fully
      // consistent upstream values (20 + 30), never a mixed intermediate
      // like 20 (new doubled) + 3 (stale tripled).
      expect(sum.value, 50);
      expect(seenSums, <int>[50]);
      expect(sumNotifications, 1);
    });

    test('outside batch, each upstream write recomputes the downstream '
        'Computed once per write (documented out-of-batch behavior)', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> doubled = Computed<int>(() => source.value * 2);
      final Computed<int> tripled = Computed<int>(() => source.value * 3);
      final List<int> seenSums = <int>[];
      final Computed<int> sum = Computed<int>(() {
        final int value = doubled.value + tripled.value;
        seenSums.add(value);
        return value;
      });

      expect(sum.value, 5);
      seenSums.clear();

      // A single write to `source` still only notifies `source`'s direct
      // listeners once each (doubled and tripled each recompute once), but
      // since both write to `sum`'s dependencies synchronously and
      // in-order, `sum` itself only recomputes once per notified
      // dependency change here (both were triggered by the same
      // `source.value =`, which notifies its own listeners in a single
      // pass) — documented so this exact call count is not accidentally
      // treated as a regression if internal notification order changes.
      source.value = 20;
      expect(sum.value, 100); // 40 + 60
      expect(seenSums.last, 100);
    });
  });

  group('Computed diamond glitch mitigation, deeper cascade', () {
    test('a diamond one level deeper (a Computed depending on the '
        'diamond-derived Computed plus a sibling branch) still recomputes '
        'exactly once with fully consistent state inside a batch', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> doubled = Computed<int>(() => source.value * 2);
      final Computed<int> tripled = Computed<int>(() => source.value * 3);
      final Computed<int> sum = Computed<int>(
        () => doubled.value + tripled.value,
      );
      final Computed<int> quadrupled = Computed<int>(() => source.value * 4);
      final List<int> seenFinals = <int>[];
      // `final_` depends on `sum` (itself a 2-level diamond over `doubled`/
      // `tripled`) *and* on `quadrupled`, a second, independent branch off
      // the same `source` — a diamond one level deeper than the one the
      // other group in this file already covers.
      final Computed<int> finalValue = Computed<int>(() {
        final int value = sum.value + quadrupled.value;
        seenFinals.add(value);
        return value;
      });

      expect(finalValue.value, 9); // (2 + 3) + 4
      seenFinals.clear();

      int finalNotifications = 0;
      finalValue.addListener(() => finalNotifications++);

      Observable.batch(() {
        source.value = 10;
      });

      // Fully consistent post-batch values: sum = 20 + 30 = 50,
      // quadrupled = 40, final = 90. Never a mixed read like 50 + 4 (stale
      // quadrupled) or 5 + 40 (stale sum).
      expect(finalValue.value, 90);
      expect(seenFinals, <int>[90]);
      expect(finalNotifications, 1);
    });
  });

  group('Computed.value read inside a still-open batch', () {
    test('reading value inside Observable.batch, after an upstream write, '
        'eagerly flushes the dirty recompute right there instead of '
        'waiting for the batch to end', () {
      final Observable<int> source = Observable<int>(1);
      int computeRuns = 0;
      final Computed<int> doubled = Computed<int>(() {
        computeRuns++;
        return source.value * 2;
      });
      expect(doubled.value, 2);
      computeRuns = 0;

      int notifications = 0;
      doubled.addListener(() => notifications++);

      late int valueSeenInsideBatch;
      Observable.batch(() {
        source.value = 5;
        // The getter's own `_flushIfDirty` check recomputes right here,
        // synchronously, instead of waiting for the batch to flush — see
        // the note on `Computed.value`.
        valueSeenInsideBatch = doubled.value;
      });

      expect(valueSeenInsideBatch, 10);
      // Recomputed exactly once (the in-batch read), not again when the
      // batch itself ends, since `_dirty` was already cleared by that read.
      expect(computeRuns, 1);
      expect(notifications, 1);
      expect(doubled.value, 10);
    });
  });

  group('Computed exception safety during a deferred batch flush', () {
    test('a Computed whose compute throws during a batch-deferred flush '
        'does not stop a sibling Computed from flushing, and the exception '
        'does not propagate out of Observable.batch', () {
      final Observable<int> source = Observable<int>(1);
      bool shouldThrow = false;
      final Computed<int> risky = Computed<int>(() {
        // Read `source` *before* the throw check (rather than after), so
        // the dependency is re-tracked even on a failing pass — exercising
        // `_recompute`'s `finally`-based re-subscription, not just the
        // happy path where `compute` returns normally.
        final int doubledValue = source.value * 2;
        if (shouldThrow) {
          throw StateError('boom during batch flush');
        }
        return doubledValue;
      });
      final Computed<int> safe = Computed<int>(() => source.value * 3);

      // Force both live (and subscribed to `source`) before the batch.
      expect(risky.value, 2);
      expect(safe.value, 3);

      int safeNotifications = 0;
      safe.addListener(() => safeNotifications++);

      shouldThrow = true;
      final List<FlutterErrorDetails> reported = _captureReportedErrors(() {
        expect(() {
          Observable.batch(() {
            source.value = 10;
          });
        }, returnsNormally);
      });

      // `risky`'s deferred recompute threw and was caught/reported in
      // isolation; `safe`'s own deferred recompute still ran and notified.
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
      expect(safeNotifications, 1);
      expect(safe.value, 30);

      // Recovery: once `shouldThrow` is turned back off, `risky` recomputes
      // normally again on the next dependency change (it wasn't left in a
      // broken/stuck-dirty state by the earlier failure).
      shouldThrow = false;
      source.value = 20;
      expect(risky.value, 40);
    });
  });
}
