import 'package:all_observer/all_observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

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

  group('Audit 1 - own and external writes to the same registry', () {
    test('direct listener external write is not suppressed as own write', () {
      final trigger = Observable<int>(0, name: 'auditSameRegistryTrigger');
      final shared = Observable<int>(0, name: 'auditSameRegistryShared');
      final seenByA = <int>[];

      var runsA = 0;
      var runsB = 0;
      var ownWriteDone = false;

      late final void Function() disposeA;
      addTearDown(() {
        disposeA();
        trigger.close();
        shared.close();
      });

      disposeA = effect(() {
        runsA++;
        if (runsA > 20) {
          fail('possível loop reativo');
        }

        final triggerValue = trigger.value;
        final sharedValue = shared.value;
        seenByA.add(sharedValue);

        if (triggerValue == 1 && !ownWriteDone) {
          ownWriteDone = true;
          shared.value = 1;
        }
      }, name: 'auditSameRegistryEffectA');

      final subscription = shared.listen((value) {
        runsB++;
        if (value == 1) {
          shared.value = 2;
        }
      });
      addTearDown(subscription.cancel);

      final reported = _captureFlutterErrors(() {
        trigger.value = 1;
      });

      expect(shared.value, 2);
      expect(seenByA, contains(2));
      expect(seenByA.last, 2);
      expect(runsA, inInclusiveRange(2, 20));
      expect(runsB, inInclusiveRange(1, 2));
      expect(reported, isEmpty);
    });

    test('other effect external write is not suppressed as own write', () {
      final trigger = Observable<int>(0, name: 'auditSameRegistryTrigger');
      final shared = Observable<int>(0, name: 'auditSameRegistryShared');
      final seenByA = <int>[];

      var runsA = 0;
      var runsB = 0;
      var ownWriteDone = false;

      late final void Function() disposeA;
      late final void Function() disposeB;
      addTearDown(() {
        disposeB();
        disposeA();
        trigger.close();
        shared.close();
      });

      disposeA = effect(() {
        runsA++;
        if (runsA > 20) {
          fail('possível loop reativo');
        }

        final triggerValue = trigger.value;
        final sharedValue = shared.value;
        seenByA.add(sharedValue);

        if (triggerValue == 1 && !ownWriteDone) {
          ownWriteDone = true;
          shared.value = 1;
        }
      }, name: 'auditSameRegistryEffectA');

      disposeB = effect(() {
        runsB++;
        final sharedValue = shared.value;
        if (sharedValue == 1) {
          shared.value = 2;
        }
      }, name: 'auditSameRegistryEffectB');

      final reported = _captureFlutterErrors(() {
        trigger.value = 1;
      });

      expect(shared.value, 2);
      expect(seenByA, contains(2));
      expect(seenByA.last, 2);
      expect(runsA, inInclusiveRange(2, 20));
      expect(runsB, greaterThanOrEqualTo(2));
      expect(reported, isEmpty);
    });

    test('computed chain external write is not suppressed as own write', () {
      final trigger = Observable<int>(0, name: 'auditSameRegistryTrigger');
      final shared = Observable<int>(0, name: 'auditSameRegistryShared');
      final mirrored = Computed<int>(
        () => trigger.value,
        name: 'auditSameRegistryComputed',
      );
      final seenByA = <int>[];

      var runsA = 0;
      var runsB = 0;
      var ownWriteDone = false;

      late final void Function() disposeA;
      late final void Function() disposeB;
      addTearDown(() {
        disposeB();
        disposeA();
        mirrored.close();
        trigger.close();
        shared.close();
      });

      disposeA = effect(() {
        runsA++;
        if (runsA > 20) {
          fail('possível loop reativo');
        }

        final triggerValue = trigger.value;
        final sharedValue = shared.value;
        seenByA.add(sharedValue);

        if (triggerValue == 1 && !ownWriteDone) {
          ownWriteDone = true;
          shared.value = 1;
        }
      }, name: 'auditSameRegistryEffectA');

      disposeB = effect(() {
        runsB++;
        if (mirrored.value == 1) {
          shared.value = 2;
        }
      }, name: 'auditSameRegistryEffectB');

      final reported = _captureFlutterErrors(() {
        trigger.value = 1;
      });

      expect(shared.value, 2);
      expect(seenByA, contains(2));
      expect(seenByA.last, 2);
      expect(runsA, inInclusiveRange(2, 20));
      expect(runsB, greaterThanOrEqualTo(2));
      expect(reported, isEmpty);
    });
  });
}
