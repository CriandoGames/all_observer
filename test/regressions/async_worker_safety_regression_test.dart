import 'dart:async';

import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableStream safety contracts', () {
    test('a synchronous streamFactory failure becomes AsyncError', () {
      final ObservableStream<int> stream = ObservableStream<int>(
        () => throw StateError('factory failed'),
        autoStart: false,
      );

      expect(stream.run, returnsNormally);
      expect(stream.value, isA<AsyncError<int>>());
      expect((stream.value as AsyncError<int>).error, isA<StateError>());
      stream.close();
    });

    test(
      'an asynchronous cancellation failure is reported and isolated',
      () async {
        final List<Object> reported = <Object>[];
        final previousReporter = CoreErrorReporting.reporter;
        CoreErrorReporting.reporter =
            (
              Object error,
              StackTrace stackTrace, {
              required String library,
              required String context,
            }) {
              reported.add(error);
            };
        addTearDown(() => CoreErrorReporting.reporter = previousReporter);

        final StreamController<int> controller = StreamController<int>(
          onCancel: () => Future<void>.error(StateError('cancel failed')),
        );
        final ObservableStream<int> stream = ObservableStream<int>(
          () => controller.stream,
        );

        expect(stream.close, returnsNormally);
        await Future<void>.delayed(Duration.zero);

        expect(reported, hasLength(1));
        expect(reported.single, isA<StateError>());
        await controller.close();
      },
    );

    test(
      'cancelOnError cancels the subscription and ignores later data',
      () async {
        bool cancelled = false;
        final StreamController<int> controller = StreamController<int>(
          onCancel: () => cancelled = true,
        );
        final ObservableStream<int> stream = ObservableStream<int>(
          () => controller.stream,
          cancelOnError: true,
        );

        controller.addError(StateError('boom'));
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, isA<AsyncError<int>>());
        expect(cancelled, isTrue);

        controller.add(99);
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, isA<AsyncError<int>>());

        stream.close();
        await controller.close();
      },
    );
  });

  group('timed worker disposal', () {
    testWidgets('interval dispose during cooldown cancels trailing callback', (
      WidgetTester tester,
    ) async {
      final Observable<int> source = Observable<int>(0);
      final List<int> seen = <int>[];
      final Worker worker = interval<int>(
        source,
        seen.add,
        time: const Duration(milliseconds: 100),
      );

      source.value = 1;
      source.value = 2;
      worker.dispose();
      expect(worker.dispose, returnsNormally);
      await tester.pump(const Duration(milliseconds: 200));

      expect(seen, <int>[1]);
      expect(worker.isDisposed, isTrue);
      expect(source.hasListeners, isFalse);
      source.close();
    });

    testWidgets('debounce remains inert after repeated disposal', (
      WidgetTester tester,
    ) async {
      final Observable<int> source = Observable<int>(0);
      int calls = 0;
      final Worker worker = debounce<int>(
        source,
        (int _) => calls++,
        time: const Duration(milliseconds: 50),
      );
      source.value = 1;

      worker.dispose();
      worker.dispose();
      await tester.pump(const Duration(milliseconds: 100));
      source.value = 2;
      await tester.pump(const Duration(milliseconds: 100));

      expect(calls, 0);
      expect(source.hasListeners, isFalse);
      source.close();
    });
  });
}
