import 'dart:async';

import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ObserverConfig.reset);

  group('Audit P0 - async resources after close', () {
    test(
      'D01 ObservableFuture.run after close does not execute factory',
      () async {
        var factoryCalls = 0;
        var notifications = 0;

        final future = ObservableFuture<int>(
          () {
            factoryCalls++;
            return Future<int>.error(StateError('closed future work'));
          },
          autoStart: false,
          name: 'auditFutureAfterClose',
        );

        future.listen((_) => notifications++);
        future.close();

        await future.run();

        expect(factoryCalls, 0);
        expect(notifications, 0);
        expect(future.value, isA<AsyncLoading<int>>());
      },
    );

    test('D02 ObservableStream.run after close does not subscribe', () async {
      var factoryCalls = 0;
      var listened = false;
      var cancelled = false;
      var notifications = 0;

      late final StreamController<int> controller;
      controller = StreamController<int>(
        onListen: () {
          listened = true;
        },
        onCancel: () {
          cancelled = true;
        },
      );

      final stream = ObservableStream<int>(
        () {
          factoryCalls++;
          return controller.stream;
        },
        autoStart: false,
        name: 'auditStreamAfterClose',
      );

      stream.listen((_) => notifications++);
      stream.close();

      stream.run();
      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(factoryCalls, 0);
      expect(listened, isFalse);
      expect(cancelled, isFalse);
      expect(notifications, 0);
      expect(stream.value, isA<AsyncLoading<int>>());

      unawaited(controller.close());
    });
  });
}
