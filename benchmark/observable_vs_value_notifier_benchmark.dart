// Manual Stopwatch-based microbenchmark: Observable<int> set/get overhead
// vs a plain ValueNotifier<int>, outside any tracking context (the common
// case for most writes in an app). No external dependency (no
// `benchmark_harness`): plain `dart:core` `Stopwatch`.
//
// This benchmark depends on `package:flutter/foundation.dart` (for
// ValueNotifier), so it cannot run under a plain `dart run` — run it with:
//   flutter test benchmark/observable_vs_value_notifier_benchmark.dart
// (flutter_test's `test()` wrapper is used purely to get a Flutter-aware
// entry point; there are no widget/expect assertions involved, only prints,
// so this stays a benchmark, not a test).
//
// NOT EXECUTED IN THIS ENVIRONMENT — see benchmark/RESULTS.md.

import 'package:all_observer/src/observable/observable.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const int kIterations = 2000000;

void main() {
  test('Observable<int> vs ValueNotifier<int> set/get overhead', () {
    _warmUp();

    final int notifierNanos = _benchValueNotifier();
    final int observableNanos = _benchObservable();

    // ignore: avoid_print
    print(
      'ValueNotifier<int>: ${notifierNanos}ns total for $kIterations '
      'set+get',
    );
    // ignore: avoid_print
    print(
      'Observable<int>:     ${observableNanos}ns total for $kIterations '
      'set+get',
    );
    // ignore: avoid_print
    print(
      'Overhead ratio (Observable / ValueNotifier): '
      '${(observableNanos / notifierNanos).toStringAsFixed(2)}x',
    );
  });
}

void _warmUp() {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  for (int i = 0; i < 1000; i++) {
    notifier.value = i;
  }
  final Observable<int> observable = Observable<int>(0);
  for (int i = 0; i < 1000; i++) {
    observable.value = i;
  }
}

int _benchValueNotifier() {
  final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  int sink = 0;
  final Stopwatch stopwatch = Stopwatch()..start();
  for (int i = 0; i < kIterations; i++) {
    notifier.value = i;
    sink += notifier.value;
  }
  stopwatch.stop();
  return sink == -1 ? -1 : stopwatch.elapsedMicroseconds * 1000;
}

int _benchObservable() {
  final Observable<int> observable = Observable<int>(0);
  int sink = 0;
  final Stopwatch stopwatch = Stopwatch()..start();
  for (int i = 0; i < kIterations; i++) {
    observable.value = i;
    sink += observable.value;
  }
  stopwatch.stop();
  return sink == -1 ? -1 : stopwatch.elapsedMicroseconds * 1000;
}
