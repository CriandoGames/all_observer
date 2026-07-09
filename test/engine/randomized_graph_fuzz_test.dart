import 'dart:math';

import 'package:all_observer/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'seeded random DAG stays consistent across 1000 source mutations',
    () {
      const int sourceCount = 40;
      const int computedCount = 300;
      const int mutations = 1000;
      final Random random = Random(20260709);
      final List<CoreObservable<int>> sources =
          List<CoreObservable<int>>.generate(
            sourceCount,
            (int index) => CoreObservable<int>(index),
          );
      final List<int Function()> actualGetters = <int Function()>[
        for (final CoreObservable<int> source in sources) () => source.value,
      ];
      final List<List<int>?> dependencies = <List<int>?>[
        for (int i = 0; i < sourceCount; i++) null,
      ];
      final List<CoreComputed<int>> computeds = <CoreComputed<int>>[];

      for (int index = 0; index < computedCount; index++) {
        final int available = actualGetters.length;
        final int dependencyCount = 1 + random.nextInt(4);
        final List<int> deps = List<int>.generate(
          dependencyCount,
          (_) => random.nextInt(available),
        ).toSet().toList();
        dependencies.add(deps);
        final CoreComputed<int> computed = CoreComputed<int>(
          () => deps.fold<int>(
            0,
            (int sum, int dep) => sum + actualGetters[dep](),
          ),
        );
        computeds.add(computed);
        actualGetters.add(() => computed.value);
      }

      List<int> calculateModel() {
        final List<int> values = <int>[
          for (final CoreObservable<int> source in sources) source.value,
        ];
        for (int index = sourceCount; index < dependencies.length; index++) {
          values.add(
            dependencies[index]!.fold<int>(
              0,
              (int sum, int dep) => sum + values[dep],
            ),
          );
        }
        return values;
      }

      for (int mutation = 0; mutation < mutations; mutation++) {
        final int sourceIndex = random.nextInt(sourceCount);
        sources[sourceIndex].value = random.nextInt(10000);
        final List<int> expected = calculateModel();

        // Check every node periodically and a random sample on every write.
        final Iterable<int> checks = mutation % 50 == 0
            ? Iterable<int>.generate(actualGetters.length)
            : Iterable<int>.generate(
                20,
                (_) => random.nextInt(actualGetters.length),
              );
        for (final int index in checks) {
          expect(
            actualGetters[index](),
            expected[index],
            reason: 'seeded DAG diverged at mutation $mutation, node $index',
          );
        }
      }

      for (final CoreComputed<int> computed in computeds.reversed) {
        computed.close();
      }
      for (final CoreObservable<int> source in sources) {
        expect(source.hasListeners, isFalse);
        source.close();
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
