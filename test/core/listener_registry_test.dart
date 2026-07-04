import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/listener_registry.dart';

/// Temporarily replaces [FlutterError.onError] with a capturing handler for
/// the duration of [run], restoring the previous handler afterwards (even
/// if [run] throws). Needed because `flutter_test`'s default
/// [FlutterError.onError] fails the current test whenever
/// [FlutterError.reportError] is called — which these tests trigger on
/// purpose, as part of the behavior under test, not as a real failure.
///
/// Substitui temporariamente [FlutterError.onError] por um handler que
/// captura os erros durante [run], restaurando o handler anterior depois
/// (mesmo que [run] lance). Necessário porque o [FlutterError.onError]
/// padrão do `flutter_test` falha o teste atual sempre que
/// [FlutterError.reportError] é chamado — o que estes testes disparam de
/// propósito, como parte do comportamento sendo testado, não como uma
/// falha real.
List<FlutterErrorDetails> captureReportedErrors(void Function() run) {
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
  group('ListenerRegistry', () {
    test('add registers a listener and notifyAll invokes it', () {
      final ListenerRegistry registry = ListenerRegistry();
      int calls = 0;
      registry.add(() => calls++);
      registry.notifyAll();
      expect(calls, 1);
    });

    test('adding the same listener twice registers it once', () {
      final ListenerRegistry registry = ListenerRegistry();
      void listener() {}
      registry.add(listener);
      registry.add(listener);
      expect(registry.length, 1);
    });

    test('disposer returned by add removes the listener', () {
      final ListenerRegistry registry = ListenerRegistry();
      int calls = 0;
      final void Function() dispose = registry.add(() => calls++);
      dispose();
      registry.notifyAll();
      expect(calls, 0);
      expect(registry.hasListeners, isFalse);
    });

    test('listener mutating the registry during notification does not '
        'affect the current notification pass', () {
      final ListenerRegistry registry = ListenerRegistry();
      final List<String> order = <String>[];
      late void Function() disposeSecond;
      void first() {
        order.add('first');
        disposeSecond();
      }

      void second() => order.add('second');
      registry.add(first);
      disposeSecond = registry.add(second);

      registry.notifyAll();

      expect(order, <String>['first', 'second']);
      expect(registry.hasListeners, isTrue);
      expect(registry.length, 1);
    });

    test('clear removes all listeners', () {
      final ListenerRegistry registry = ListenerRegistry();
      registry.add(() {});
      registry.add(() {});
      registry.clear();
      expect(registry.hasListeners, isFalse);
    });

    test('notifyAll on an empty registry is a no-op', () {
      final ListenerRegistry registry = ListenerRegistry();
      expect(() => registry.notifyAll(), returnsNormally);
    });

    test('an exception thrown by one listener does not stop the others '
        'from running, and does not propagate out of notifyAll', () {
      final ListenerRegistry registry = ListenerRegistry();
      final List<String> order = <String>[];
      registry.add(() => order.add('first'));
      registry.add(() => throw StateError('boom'));
      registry.add(() => order.add('third'));

      final List<FlutterErrorDetails> reported = captureReportedErrors(
        () => expect(() => registry.notifyAll(), returnsNormally),
      );

      expect(order, <String>['first', 'third']);
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<StateError>());
    });

    test('notifyAll does not overflow the stack on a synchronous update '
        'cycle (A notifies B, B notifies A, ...); it stops at '
        'kMaxNotificationDepth instead', () {
      final ListenerRegistry a = ListenerRegistry();
      final ListenerRegistry b = ListenerRegistry();
      int aRuns = 0;
      int bRuns = 0;
      a.add(() {
        aRuns++;
        b.notifyAll();
      });
      b.add(() {
        bRuns++;
        a.notifyAll();
      });

      final List<FlutterErrorDetails> reported = captureReportedErrors(
        () => expect(() => a.notifyAll(), returnsNormally),
      );
      // Depth guard caps recursion at kMaxNotificationDepth; both counters
      // stay bounded instead of growing until a StackOverflowError.
      expect(aRuns, lessThanOrEqualTo(kMaxNotificationDepth + 1));
      expect(bRuns, lessThanOrEqualTo(kMaxNotificationDepth + 1));
      expect(reported, hasLength(1));
      expect(reported.single.exception, isA<FlutterError>());
    });
  });
}
