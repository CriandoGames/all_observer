import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/async/async_state.dart';
import 'package:all_observer/src/observable/async/observable_stream.dart';

void main() {
  group('ObservableStream', () {
    test(
      'autoStart subscribes immediately; each event becomes AsyncData',
      () async {
        final StreamController<int> controller = StreamController<int>();
        final ObservableStream<int> stream = ObservableStream<int>(
          () => controller.stream,
        );
        expect(stream.value, isA<AsyncLoading<int>>());

        controller.add(1);
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, const AsyncData<int>(1));

        controller.add(2);
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, const AsyncData<int>(2));

        await controller.close();
        stream.close();
      },
    );

    test('autoStart: false does not subscribe until run() is called', () async {
      int listenCalls = 0;
      final StreamController<int> controller = StreamController<int>();
      final ObservableStream<int> stream = ObservableStream<int>(() {
        listenCalls++;
        return controller.stream;
      }, autoStart: false);
      expect(listenCalls, 0);
      expect(stream.value, isA<AsyncLoading<int>>());

      stream.run();
      expect(listenCalls, 1);
      controller.add(5);
      await Future<void>.delayed(Duration.zero);
      expect(stream.value, const AsyncData<int>(5));

      await controller.close();
      stream.close();
    });

    test('a stream error becomes AsyncError', () async {
      final StreamController<int> controller = StreamController<int>();
      final ObservableStream<int> stream = ObservableStream<int>(
        () => controller.stream,
      );
      controller.addError(StateError('boom'));
      await Future<void>.delayed(Duration.zero);
      expect(stream.value, isA<AsyncError<int>>());
      final AsyncError<int> errorState = stream.value as AsyncError<int>;
      expect(errorState.error, isA<StateError>());

      await controller.close();
      stream.close();
    });

    test(
      'refresh cancels the old subscription and preserves previousData',
      () async {
        final StreamController<int> firstController = StreamController<int>();
        final StreamController<int> secondController = StreamController<int>();
        int calls = 0;
        final ObservableStream<int> stream = ObservableStream<int>(() {
          calls++;
          return calls == 1 ? firstController.stream : secondController.stream;
        });

        firstController.add(1);
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, const AsyncData<int>(1));

        stream.refresh();
        final AsyncState<int> mid = stream.value;
        expect(mid, isA<AsyncLoading<int>>());
        expect((mid as AsyncLoading<int>).previousData, 1);

        // The old (now-cancelled) controller's event must never resurface.
        firstController.add(99);
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, isA<AsyncLoading<int>>());

        secondController.add(2);
        await Future<void>.delayed(Duration.zero);
        expect(stream.value, const AsyncData<int>(2));

        await firstController.close();
        await secondController.close();
        stream.close();
      },
    );

    test('close() cancels the active subscription', () async {
      bool cancelled = false;
      final StreamController<int> controller = StreamController<int>(
        onCancel: () => cancelled = true,
      );
      final ObservableStream<int> stream = ObservableStream<int>(
        () => controller.stream,
      );
      expect(stream.isClosed, isFalse);
      stream.close();
      await Future<void>.delayed(Duration.zero);
      expect(cancelled, isTrue);
      expect(stream.isClosed, isTrue);

      await controller.close();
    });

    test(
      'an event arriving after close() is discarded without writing',
      () async {
        final StreamController<int> controller = StreamController<int>(
          sync: true,
        );
        final ObservableStream<int> stream = ObservableStream<int>(
          () => controller.stream,
        );
        stream.close();
        controller.add(1);
        await Future<void>.delayed(Duration.zero);
        expect(stream.isClosed, isTrue);

        await controller.close();
      },
    );
  });
}
