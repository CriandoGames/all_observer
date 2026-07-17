import 'package:all_observer/all_observer.dart';
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
    if (_index == 2) {
      throw StateError('iterable failed');
    }
    return true;
  }
}

void main() {
  tearDown(ObserverConfig.reset);

  group('remaining audit regressions', () {
    test('effect sees an external same-registry write in the same flush', () {
      final trigger = Observable<int>(0, name: 'regressionTrigger');
      final shared = Observable<int>(0, name: 'regressionShared');
      final seenByEffect = <int>[];

      var ownWriteDone = false;
      late final void Function() disposeEffect;

      disposeEffect = effect(() {
        final triggerValue = trigger.value;
        final sharedValue = shared.value;
        seenByEffect.add(sharedValue);

        if (triggerValue == 1 && !ownWriteDone) {
          ownWriteDone = true;
          shared.value = 1;
        }
      }, name: 'regressionSameRegistryEffect');

      final subscription = shared.listen((value) {
        if (value == 1) {
          shared.value = 2;
        }
      });

      addTearDown(() {
        subscription.cancel();
        disposeEffect();
        shared.close();
        trigger.close();
      });

      trigger.value = 1;

      expect(shared.value, 2);
      expect(seenByEffect, contains(2));
      expect(seenByEffect.last, 2);
    });

    test('ObservableSet.addAll is atomic when the iterable throws', () {
      final items = ObservableSet<int>(<int>{10}, 'regressionSetAddAll');
      addTearDown(items.close);

      var notifications = 0;
      items.listen(() => notifications++);

      expect(
        () => items.addAll(const _ThrowingIterable()),
        throwsA(isA<StateError>()),
      );

      expect(items.toSet(), <int>{10});
      expect(notifications, 0);
    });

    test('ObservableSet.toSet registers reactive reads', () {
      final source = ObservableSet<int>(<int>{1, 2}, 'regressionSetToSet');
      final seen = <Set<int>>[];

      final derived = Computed<int>(
        () => source.toSet().length,
        name: 'regressionSetToSetComputed',
      );
      late final void Function() disposeEffect;
      disposeEffect = effect(() {
        seen.add(source.toSet());
      }, name: 'regressionSetToSetEffect');

      addTearDown(() {
        disposeEffect();
        derived.close();
        source.close();
      });

      expect(derived.value, 2);

      source.add(3);

      expect(derived.value, 3);
      expect(seen, <Set<int>>[
        <int>{1, 2},
        <int>{1, 2, 3},
      ]);
    });
  });
}
