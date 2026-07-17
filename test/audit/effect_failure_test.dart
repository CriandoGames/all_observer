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

  group('Audit P0 - effect scheduling and failures', () {
    test('B01 cleans up dependencies when effect creation throws', () {
      // Setup: creation runs the effect immediately, reads source and throws.
      final source = Observable<int>(0, name: 'auditEffectSource');
      addTearDown(source.close);

      var runs = 0;
      Object? creationError;

      try {
        effect(() {
          runs++;
          source.value;
          throw StateError('creation failed');
        }, name: 'auditZombieEffect');
      } catch (error) {
        creationError = error;
      }

      expect(creationError, isA<StateError>());
      expect(runs, 1);

      // Action: no disposer was returned, but the failed effect must have
      // already cleaned up its temporary dependency.
      final reported = _captureFlutterErrors(() {
        source.value = 1;
      });

      expect(runs, 1);
      expect(reported, isEmpty);
    });

    test('B03 indirect invalidation in the same flush converges', () {
      // Setup: source -> computed -> bridge observable -> effect B.
      final source = Observable<int>(0, name: 'auditIndirectSource');
      final bridge = Observable<int>(0, name: 'auditIndirectBridge');
      final doubled = Computed<int>(
        () => source.value * 2,
        name: 'auditIndirectComputed',
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
      }, name: 'auditEffectA');

      disposeB = effect(() {
        final value = bridge.value;
        seenByB.add(value);
        if (value == 2) {
          source.value = 2;
        }
      }, name: 'auditEffectB');

      // Action: B sees 2, writes source, A derives 4 and invalidates B again.
      source.value = 1;

      // B must not get stuck at the intermediate value.
      expect(seenByB, <int>[0, 2, 4]);
      expect(seenByB.last, 4);
      expect(source.value, 2);
      expect(bridge.value, 4);
      expect(doubled.value, 4);
    });
  });
}
