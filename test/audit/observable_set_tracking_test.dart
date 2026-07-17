import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

String _setSummary(Set<int> values) {
  final sorted = values.toList()..sort();
  return sorted.join(',');
}

void main() {
  tearDown(ObserverConfig.reset);

  group('Audit 3 - ObservableSet.toSet tracking', () {
    test('Computed based exclusively on toSet reacts to mutations', () {
      final source = ObservableSet<int>(<int>{1, 2}, 'auditSet');
      var computations = 0;
      final derived = Computed<int>(() {
        computations++;
        return source.toSet().length;
      }, name: 'auditSetToSetComputed');

      addTearDown(() {
        derived.close();
        source.close();
      });

      expect(derived.value, 2);
      expect(computations, 1);

      source.add(3);

      expect(source.toSet(), <int>{1, 2, 3});
      expect(derived.value, 3);
      expect(computations, greaterThan(1));
    });

    test('effect based exclusively on toSet reacts to mutations', () {
      final source = ObservableSet<int>(<int>{1, 2}, 'auditSet');
      final seen = <Set<int>>[];
      var runs = 0;

      late final void Function() disposeEffect;
      addTearDown(() {
        disposeEffect();
        source.close();
      });

      disposeEffect = effect(() {
        runs++;
        seen.add(source.toSet());
      }, name: 'auditSetToSetEffect');

      source.add(3);

      expect(runs, 2);
      expect(seen, <Set<int>>[
        <int>{1, 2},
        <int>{1, 2, 3},
      ]);
      expect(seen.last, <int>{1, 2, 3});
    });

    test('toSet invalidates like positive ObservableSet read controls', () {
      final source = ObservableSet<int>(<int>{1, 2}, 'auditSetControls');

      var lengthComputations = 0;
      var containsComputations = 0;
      var iterationComputations = 0;
      var toListComputations = 0;
      var toSetComputations = 0;

      final byLength = Computed<int>(() {
        lengthComputations++;
        return source.length;
      }, name: 'auditSetLengthComputed');
      final byContains = Computed<bool>(() {
        containsComputations++;
        return source.contains(3);
      }, name: 'auditSetContainsComputed');
      final byIteration = Computed<String>(() {
        iterationComputations++;
        return _setSummary(source);
      }, name: 'auditSetIterationComputed');
      final byToList = Computed<int>(() {
        toListComputations++;
        return source.toList().length;
      }, name: 'auditSetToListComputed');
      final byToSet = Computed<int>(() {
        toSetComputations++;
        return source.toSet().length;
      }, name: 'auditSetToSetControlComputed');

      addTearDown(() {
        byToSet.close();
        byToList.close();
        byIteration.close();
        byContains.close();
        byLength.close();
        source.close();
      });

      expect(byLength.value, 2);
      expect(byContains.value, isFalse);
      expect(byIteration.value, '1,2');
      expect(byToList.value, 2);
      expect(byToSet.value, 2);

      source.add(3);

      expect(byLength.value, 3);
      expect(byContains.value, isTrue);
      expect(byIteration.value, '1,2,3');
      expect(byToList.value, 3);
      expect(byToSet.value, 3);

      expect(lengthComputations, 2);
      expect(containsComputations, 2);
      expect(iterationComputations, 2);
      expect(toListComputations, 2);
      expect(toSetComputations, 2);
    });

    test('toSet returns an independent copy', () {
      final source = ObservableSet<int>(<int>{1, 2}, 'auditSetCopy');
      addTearDown(source.close);

      final copy = source.toSet();
      copy.add(999);

      expect(copy, <int>{1, 2, 999});
      expect(source.toSet(), <int>{1, 2});
    });
  });
}
