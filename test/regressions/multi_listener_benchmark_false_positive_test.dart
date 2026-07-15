import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

const int _listenerCount = 1000;

Iterable<WarningEvent> _listenerLeakWarnings(RecordingInspector recorder) {
  return recorder.events.whereType<WarningEvent>().where(
    (WarningEvent event) => event.label.contains('listeners'),
  );
}

final class _DisposeAuditInspector extends ObserverInspector {
  int disposeEvents = 0;
  int nonZeroListenerDisposes = 0;

  @override
  void onDispose(ObservableDisposeEvent event) {
    disposeEvents++;
    if (event.listenerCount != 0) {
      nonZeroListenerDisposes++;
    }
  }
}

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('multi-listener benchmark warning audit', () {
    test('single-listener notification is the positive control', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.warnings = false;
      ObserverConfig.inspectors.add(recorder);
      final Observable<int> counter = Observable<int>(
        0,
        name: 'single-listener-counter',
      );
      int calls = 0;

      final ObservableSubscription subscription = counter.listen(
        (int _) => calls++,
      );

      expect(counter.hasListeners, isTrue);
      expect(_listenerLeakWarnings(recorder), isEmpty);

      counter.value = 1;
      expect(calls, 1);

      subscription.cancel();
      expect(subscription.isActive, isFalse);
      expect(counter.hasListeners, isFalse);

      counter.value = 2;
      expect(calls, 1);

      recorder.clear();
      counter.close();
      final ObservableDisposeEvent disposeEvent = recorder.events
          .whereType<ObservableDisposeEvent>()
          .single;
      expect(disposeEvent.listenerCount, 0);
    });

    test(
      '1k active listeners trips the leak heuristic but cancels cleanly',
      () {
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.warnings = false;
        ObserverConfig.inspectors.add(recorder);
        final Observable<int> counter = Observable<int>(
          0,
          name: 'benchmark-counter',
        );
        int calls = 0;

        final List<ObservableSubscription> subscriptions =
            List<ObservableSubscription>.generate(
              _listenerCount,
              (_) => counter.listen((int _) => calls++),
            );

        expect(counter.hasListeners, isTrue);
        final List<WarningEvent> warnings = _listenerLeakWarnings(
          recorder,
        ).toList();
        expect(warnings, isNotEmpty);
        expect(warnings.first.label, contains('50+ listeners'));

        counter.value = 1;
        expect(calls, _listenerCount);

        for (final ObservableSubscription subscription in subscriptions) {
          subscription.cancel();
        }

        expect(
          subscriptions.every(
            (ObservableSubscription subscription) => !subscription.isActive,
          ),
          isTrue,
        );
        expect(counter.hasListeners, isFalse);

        calls = 0;
        counter.value = 2;
        expect(calls, 0);
        counter.close();
      },
    );

    test(
      'raising the intended fanout threshold removes the benchmark warning',
      () {
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.warnings = false;
        ObserverConfig.listenerLeakThreshold = _listenerCount + 1;
        ObserverConfig.inspectors.add(recorder);
        final Observable<int> counter = Observable<int>(
          0,
          name: 'benchmark-counter',
        );
        int calls = 0;

        final List<ObservableSubscription> subscriptions =
            List<ObservableSubscription>.generate(
              _listenerCount,
              (_) => counter.listen((int _) => calls++),
            );

        expect(_listenerLeakWarnings(recorder), isEmpty);

        counter.value = 1;
        expect(calls, _listenerCount);

        for (final ObservableSubscription subscription in subscriptions) {
          subscription.cancel();
        }

        expect(counter.hasListeners, isFalse);
        counter.close();
      },
    );

    test(
      'create-listen-mutate-cancel-close cycles do not retain listeners',
      () {
        const int cycles = 1000;
        final _DisposeAuditInspector inspector = _DisposeAuditInspector();
        ObserverConfig.warnings = false;
        ObserverConfig.inspectors.add(inspector);

        for (int cycle = 0; cycle < cycles; cycle++) {
          final Observable<int> counter = Observable<int>(
            0,
            name: 'cycle-$cycle',
          );
          int calls = 0;
          final ObservableSubscription subscription = counter.listen(
            (int _) => calls++,
          );

          counter.value = 1;
          expect(calls, 1, reason: 'cycle $cycle dispatch');

          subscription.cancel();
          expect(counter.hasListeners, isFalse, reason: 'cycle $cycle cancel');

          counter.close();
        }

        expect(inspector.disposeEvents, cycles);
        expect(inspector.nonZeroListenerDisposes, 0);
      },
    );
  });
}
