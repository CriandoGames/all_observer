import 'dart:async';

import 'package:all_observer/all_observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ThrowingIterable extends Iterable<int> {
  const _ThrowingIterable();

  @override
  Iterator<int> get iterator => _ThrowingIterator();
}

final class _ThrowingIterator implements Iterator<int> {
  int _index = -1;

  @override
  int get current => _index;

  @override
  bool moveNext() {
    _index++;
    if (_index == 3) {
      throw StateError('iterable failed');
    }
    return _index < 5;
  }
}

List<FlutterErrorDetails> _captureFlutterErrors(void Function() run) {
  final previous = FlutterError.onError;
  final reported = <FlutterErrorDetails>[];
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

  group('confirmed audit regressions', () {
    test('computed retries after an initial compute error', () {
      final source = Observable<int>(1, name: 'regressionSource');
      final computed = Computed<int>(() {
        final value = source.value;
        if (value == 1) {
          throw StateError('initial failure');
        }
        return value + 40;
      }, name: 'regressionComputed');

      addTearDown(computed.close);
      addTearDown(source.close);

      expect(() => computed.value, throwsA(isA<StateError>()));

      source.value = 2;

      expect(computed.value, 42);
    });

    test('failed effect creation cleans up tracked dependencies', () {
      final source = Observable<int>(0, name: 'regressionEffectSource');
      addTearDown(source.close);

      var runs = 0;

      expect(
        () => effect(() {
          runs++;
          source.value;
          throw StateError('creation failed');
        }, name: 'regressionFailedEffect'),
        throwsA(isA<StateError>()),
      );

      final reported = _captureFlutterErrors(() {
        source.value = 1;
      });

      expect(runs, 1);
      expect(reported, isEmpty);
    });

    test('indirect same-flush effect invalidation converges', () {
      final source = Observable<int>(0, name: 'regressionIndirectSource');
      final bridge = Observable<int>(0, name: 'regressionIndirectBridge');
      final doubled = Computed<int>(
        () => source.value * 2,
        name: 'regressionIndirectComputed',
      );
      final seenByB = <int>[];

      late final void Function() disposeA;
      late final void Function() disposeB;
      addTearDown(() {
        disposeB();
        disposeA();
        doubled.close();
        bridge.close();
        source.close();
      });

      disposeA = effect(() {
        bridge.value = doubled.value;
      }, name: 'regressionEffectA');

      disposeB = effect(() {
        final value = bridge.value;
        seenByB.add(value);
        if (value == 2) {
          source.value = 2;
        }
      }, name: 'regressionEffectB');

      source.value = 1;

      expect(seenByB, <int>[0, 2, 4]);
      expect(bridge.value, 4);
      expect(doubled.value, 4);
    });

    test(
      'failed batch keeps computeds consistent without direct notification',
      () {
        final source = Observable<int>(0, name: 'regressionBatchSource');
        final computed = Computed<int>(
          () => source.value * 2,
          name: 'regressionBatchComputed',
        );

        var sourceNotifications = 0;
        var computedNotifications = 0;
        final effectSeen = <int>[];

        final sourceSub = source.listen((_) => sourceNotifications++);
        final computedSub = computed.listen((_) => computedNotifications++);
        final disposeEffect = effect(() {
          effectSeen.add(computed.value);
        }, name: 'regressionBatchEffect');

        addTearDown(() {
          disposeEffect();
          computedSub.cancel();
          sourceSub.cancel();
          computed.close();
          source.close();
        });

        expect(computed.value, 0);

        expect(
          () => Observable.batch(() {
            source.value = 1;
            throw StateError('batch failed');
          }),
          throwsA(isA<StateError>()),
        );

        expect(source.value, 1);
        expect(sourceNotifications, 0);
        expect(computedNotifications, 0);
        expect(effectSeen, <int>[0]);

        expect(computed.value, 2);
        expect(computedNotifications, 1);
        expect(effectSeen, <int>[0, 2]);
      },
    );

    test('ObservableFuture.run after close does not execute factory', () async {
      var factoryCalls = 0;
      var notifications = 0;

      final future = ObservableFuture<int>(
        () {
          factoryCalls++;
          return Future<int>.error(StateError('closed future work'));
        },
        autoStart: false,
        name: 'regressionFutureAfterClose',
      );

      future.listen((_) => notifications++);
      future.close();

      await future.run();

      expect(factoryCalls, 0);
      expect(notifications, 0);
      expect(future.value, isA<AsyncLoading<int>>());
    });

    test('ObservableStream.run after close does not subscribe', () async {
      var factoryCalls = 0;
      var listened = false;
      var notifications = 0;

      late final StreamController<int> controller;
      controller = StreamController<int>(
        onListen: () {
          listened = true;
        },
      );

      final stream = ObservableStream<int>(
        () {
          factoryCalls++;
          return controller.stream;
        },
        autoStart: false,
        name: 'regressionStreamAfterClose',
      );

      stream.listen((_) => notifications++);
      stream.close();

      stream.run();
      controller.add(1);
      await Future<void>.delayed(Duration.zero);

      expect(factoryCalls, 0);
      expect(listened, isFalse);
      expect(notifications, 0);
      expect(stream.value, isA<AsyncLoading<int>>());

      unawaited(controller.close());
    });

    test('ObservableList.addAll is atomic when the iterable throws', () {
      final items = ObservableList<int>(<int>[10], 'regressionAddAll');
      addTearDown(items.close);

      var notifications = 0;
      items.listen(() => notifications++);

      expect(
        () => items.addAll(const _ThrowingIterable()),
        throwsA(isA<StateError>()),
      );

      expect(items.toList(), <int>[10]);
      expect(notifications, 0);
    });

    test('ObservableList.sort is atomic when the comparator throws', () {
      final items = ObservableList<int>(<int>[5, 4, 3, 2, 1], 'regressionSort');
      addTearDown(items.close);

      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      expect(
        () => items.sort((a, b) {
          calls++;
          if (calls == 3) {
            throw StateError('comparator failed');
          }
          return a.compareTo(b);
        }),
        throwsA(isA<StateError>()),
      );

      expect(calls, 3);
      expect(items.toList(), <int>[5, 4, 3, 2, 1]);
      expect(notifications, 0);
    });
  });
}
