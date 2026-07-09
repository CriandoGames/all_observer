import 'dart:io';

import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('20k create-track-update-dispose cycles stay structurally clean and '
      'within a generous RSS growth guard', () {
    const int cycles = 20000;

    // Warm up JIT/runtime allocations before taking the baseline.
    for (int i = 0; i < 500; i++) {
      final Observable<int> source = Observable<int>(i);
      final Computed<int> computed = Computed<int>(() => source.value + 1);
      computed.value;
      computed.close();
      source.close();
    }
    final int rssBefore = ProcessInfo.currentRss;

    for (int i = 0; i < cycles; i++) {
      final Observable<int> source = Observable<int>(i);
      final Computed<int> computed = Computed<int>(() => source.value + 1);
      final void Function() disposeEffect = effect(() => computed.value);
      final Worker worker = ever<int>(source, (_) {});

      source.value = i + 1;

      worker.dispose();
      disposeEffect();
      computed.close();
      expect(source.hasListeners, isFalse, reason: 'cycle $i retained a link');
      source.close();
    }

    final int growthBytes = ProcessInfo.currentRss - rssBefore;
    const int maxGrowthBytes = 256 * 1024 * 1024;
    expect(
      growthBytes,
      lessThan(maxGrowthBytes),
      reason:
          'RSS grew by ${growthBytes ~/ (1024 * 1024)} MiB. This generous '
          'guard catches runaway retention; use DevTools heap snapshots '
          'for precise leak attribution.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
