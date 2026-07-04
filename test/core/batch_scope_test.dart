import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/batch_scope.dart';
import 'package:all_observer/src/observable/observable.dart';

/// Captures [FlutterError.reportError] calls for the duration of [run].
/// Needed because flutter_test's default handler fails the test on any
/// reported error, but these tests trigger errors intentionally.
///
/// Captura chamadas a [FlutterError.reportError] durante [run].
/// Necessário porque o handler padrão do flutter_test falha o teste em
/// qualquer erro reportado, mas estes testes disparam erros intencionalmente.
List<FlutterErrorDetails> _captureErrors(void Function() run) {
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
  group('BatchScope flush wave limit (T1.1)', () {
    test(
      'mutual cycle via listen inside batch terminates, reports error, '
      'does not hang',
      () {
        // Two observables whose listeners write to each other — the classic
        // cycle that previously caused an infinite flush loop inside batch.
        final Observable<int> a = Observable<int>(0);
        final Observable<int> b = Observable<int>(0);

        // Cap values to prevent the writes from being identical (same value
        // skips notification) before the wave limit fires.
        a.listen((int v) {
          if (v < 200) {
            b.value = v + 1;
          }
        });
        b.listen((int v) {
          if (v < 200) {
            a.value = v + 1;
          }
        });

        final List<FlutterErrorDetails> reported = _captureErrors(() {
          // Must return (not hang); fakeAsync-style timeout is implicit in
          // synchronous test execution — if this blocks, the test runner
          // itself times out.
          expect(
            () => Observable.batch(() {
              a.value = 1;
            }),
            returnsNormally,
          );
        });

        // The wave limit fired and was reported exactly once.
        expect(reported, hasLength(1));
        expect(reported.single.exception, isA<FlutterError>());
        expect(
          reported.single.exception.toString(),
          contains('Possible in-batch update cycle'),
        );
      },
    );

    test(
      'a legitimate cascade with 3 chained observables (far fewer than '
      'kMaxFlushWaves) still completes correctly',
      () {
        // Chain: a → b → c, each listener writes the next. Needs exactly
        // 2 extra waves after the first (a→b in wave 1, b→c in wave 2,
        // nothing pending in wave 3 → loop exits). Well under 100.
        final Observable<int> a = Observable<int>(0);
        final Observable<int> b = Observable<int>(0);
        final Observable<int> c = Observable<int>(0);

        a.listen((int v) => b.value = v + 10);
        b.listen((int v) => c.value = v + 10);

        final List<FlutterErrorDetails> reported = _captureErrors(() {
          Observable.batch(() {
            a.value = 1;
          });
        });

        // No error — the cascade is legitimate.
        expect(reported, isEmpty);
        expect(b.value, 11);
        expect(c.value, 21);
      },
    );

    test(
      'the same mutual cycle OUTSIDE a batch is caught by the old '
      'kMaxNotificationDepth guard (regression)',
      () {
        final Observable<int> a = Observable<int>(0);
        final Observable<int> b = Observable<int>(0);

        a.listen((int v) {
          if (v < 200) {
            b.value = v + 1;
          }
        });
        b.listen((int v) {
          if (v < 200) {
            a.value = v + 1;
          }
        });

        final List<FlutterErrorDetails> reported = _captureErrors(() {
          expect(() => a.value = 1, returnsNormally);
        });

        // The depth guard fired (not the wave guard).
        expect(reported, hasLength(greaterThanOrEqualTo(1)));
        expect(reported.first.exception, isA<FlutterError>());
        // The message mentions kMaxNotificationDepth (the old guard).
        expect(
          reported.first.exception.toString(),
          contains('possible update cycle detected'),
        );
      },
    );

    test('kMaxFlushWaves is exported and has the documented value', () {
      expect(kMaxFlushWaves, 100);
    });
  });
}
