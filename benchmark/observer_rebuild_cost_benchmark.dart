// Manual Stopwatch-based microbenchmark: cost of an Observer rebuild that
// reads 1, 10, or 50 distinct Observable<int> dependencies. Measures pure
// tracking overhead (DependencyTracker.track + reportRead per dependency)
// by driving the widget tree directly with WidgetTester, not by timing
// production `flutter run` frames.
//
// Run with: flutter test benchmark/observer_rebuild_cost_benchmark.dart
//
// NOT EXECUTED IN THIS ENVIRONMENT — see benchmark/RESULTS.md.

import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const int kRebuilds = 2000;

void main() {
  for (final int depCount in <int>[1, 10, 50]) {
    testWidgets('Observer rebuild cost with $depCount observables', (
      tester,
    ) async {
      final List<Observable<int>> deps = List<Observable<int>>.generate(
        depCount,
        (int i) => Observable<int>(i),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Observer(() {
            int sum = 0;
            for (final Observable<int> dep in deps) {
              sum += dep.value;
            }
            return Text('$sum');
          }),
        ),
      );

      final Stopwatch stopwatch = Stopwatch()..start();
      for (int i = 0; i < kRebuilds; i++) {
        deps[i % depCount].value = i;
        await tester.pump();
      }
      stopwatch.stop();

      final double perRebuildMicros = stopwatch.elapsedMicroseconds / kRebuilds;
      // ignore: avoid_print
      print(
        'depCount=$depCount: ${stopwatch.elapsedMicroseconds}us total for '
        '$kRebuilds rebuilds (${perRebuildMicros.toStringAsFixed(2)}us/'
        'rebuild)',
      );
    });
  }
}
