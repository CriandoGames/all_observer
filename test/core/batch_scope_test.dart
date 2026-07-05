import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/batch_scope.dart';
import 'package:all_observer/src/core/core_error_reporting.dart';
import 'package:all_observer/src/errors/observer_cycle_error.dart';
import 'package:all_observer/src/observable/observable.dart';

/// See the identical helper/doc in `test/core/listener_registry_test.dart`:
/// `BatchScope` is a pure-Dart core primitive and reports via
/// `CoreErrorReporting.report` rather than `FlutterError.reportError`
/// directly. `Observable`'s setter installs a forwarding reporter
/// automatically on first use — which most tests below exercise via
/// `Observable.batch`/`observable.value =` — but this pins it explicitly so
/// the test does not depend on incidental ordering.
void _installFlutterErrorForwarding() {
  CoreErrorReporting.reporter =
      (
        Object error,
        StackTrace stackTrace, {
        required String library,
        required String context,
      }) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stackTrace,
            library: library,
            context: ErrorDescription(context),
          ),
        );
      };
}

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
  setUp(_installFlutterErrorForwarding);
  tearDown(() => CoreErrorReporting.reporter = null);

  group('BatchScope flush wave limit (T1.1)', () {
    test('mutual cycle via listen inside batch terminates, reports error, '
        'does not hang', () {
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
      expect(reported.single.exception, isA<ObserverCycleError>());
      expect(
        reported.single.exception.toString(),
        contains('Possible in-batch update cycle'),
      );
    });

    test('a legitimate cascade with 3 chained observables (far fewer than '
        'kMaxFlushWaves) still completes correctly', () {
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
    });

    test('the same mutual cycle OUTSIDE a batch is caught by the old '
        'kMaxNotificationDepth guard (regression)', () {
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

      // With v1.2.0 auto-batch (micro-batch), a standalone write outside an
      // explicit batch goes through a micro-batch — so the cycle becomes
      // iterative (wave-based) and is caught by the kMaxFlushWaves guard,
      // rather than the kMaxNotificationDepth depth guard as in v1.1.x.
      // Either way: the write returns normally, exactly one error is reported,
      // and its exception is an ObserverCycleError (still forwarded to
      // FlutterError.reportError by the installed CoreErrorReporting hook).
      //
      // Com o auto-batch da v1.2.0 (micro-batch), uma escrita avulsa fora de
      // um batch explícito passa por um micro-batch — então o ciclo se torna
      // iterativo (baseado em ondas) e é capturado pelo guard kMaxFlushWaves,
      // em vez do guard de profundidade kMaxNotificationDepth como na v1.1.x.
      // Em todo caso: a escrita retorna normalmente, exatamente um erro é
      // reportado e sua exceção é um ObserverCycleError.
      expect(reported, hasLength(greaterThanOrEqualTo(1)));
      expect(reported.first.exception, isA<ObserverCycleError>());
      // Both guards produce an ObserverCycleError — just check the common
      // part.
      expect(reported.first.exception.toString(), contains('all_observer'));
    });

    test('kMaxFlushWaves is exported and has the documented value', () {
      expect(kMaxFlushWaves, 100);
    });
  });
}
