// Manual Stopwatch-based microbenchmark + notification-count check for
// ObservableList.addAll(1000): confirms the fix in
// lib/src/observable/collections/observable_list.dart notifies listeners
// exactly once per addAll call, regardless of element count, and reports
// wall-clock time for the call itself.
//
// Run with: flutter test benchmark/observable_list_addall_benchmark.dart
//
// NOT EXECUTED IN THIS ENVIRONMENT — see benchmark/RESULTS.md.

import 'package:all_observer/src/observable/collections/observable_list.dart';
import 'package:flutter_test/flutter_test.dart';

const int kElementCount = 1000;
const int kRuns = 500;

void main() {
  test('ObservableList.addAll($kElementCount) notification count + timing', () {
    int totalNotifications = 0;
    int totalMicros = 0;

    for (int run = 0; run < kRuns; run++) {
      final ObservableList<int> items = ObservableList<int>();
      int notifications = 0;
      items.listen(() => notifications++);

      final Stopwatch stopwatch = Stopwatch()..start();
      items.addAll(List<int>.generate(kElementCount, (int i) => i));
      stopwatch.stop();

      totalNotifications += notifications;
      totalMicros += stopwatch.elapsedMicroseconds;
    }

    // ignore: avoid_print
    print(
      'addAll($kElementCount) over $kRuns runs: '
      '${totalNotifications / kRuns} notifications/run (expected 1.0), '
      '${(totalMicros / kRuns).toStringAsFixed(2)}us/run',
    );

    expect(totalNotifications, kRuns); // exactly 1 notification per run
  });
}
