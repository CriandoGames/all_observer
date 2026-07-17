import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ObserverConfig.reset);

  group('Audit P0 - batch exceptions', () {
    test(
      'C01 failed batch mutates source but discards queued notifications',
      () {
        // Setup: source has a direct listener, a computed, and an effect.
        final source = Observable<int>(0, name: 'auditBatchSource');
        final computed = Computed<int>(
          () => source.value * 2,
          name: 'auditBatchComputed',
        );

        var sourceNotifications = 0;
        var computedNotifications = 0;
        final effectSeen = <int>[];

        final sourceSub = source.listen((_) => sourceNotifications++);
        final computedSub = computed.listen((_) => computedNotifications++);
        final disposeEffect = effect(() {
          effectSeen.add(computed.value);
        }, name: 'auditBatchEffect');

        addTearDown(() {
          disposeEffect();
          computedSub.cancel();
          sourceSub.cancel();
          computed.close();
          source.close();
        });

        expect(computed.value, 0);

        // Action: write inside a batch, then fail before the batch completes.
        expect(
          () => Observable.batch(() {
            source.value = 1;
            throw StateError('batch failed');
          }),
          throwsA(isA<StateError>()),
        );

        // The mutation remains and direct source notifications are discarded,
        // but the already-live computed is marked stale and reconciles on
        // the next read.
        expect(source.value, 1);
        expect(sourceNotifications, 0);
        expect(computedNotifications, 0);
        expect(effectSeen, <int>[0]);
        expect(computed.value, 2);
        expect(computedNotifications, 1);
        expect(effectSeen, <int>[0, 2]);

        source.value = 1;
        expect(sourceNotifications, 0);

        source.value = 2;
        expect(sourceNotifications, 1);
        expect(computed.value, 4);
        expect(effectSeen.last, 4);
      },
    );
  });
}
