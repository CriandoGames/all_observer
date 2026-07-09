import 'package:all_observer/all_observer.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

const int _iterations = 200000;

int _median(List<int> values) {
  values.sort();
  return values[values.length ~/ 2];
}

int _timeValueNotifier() {
  final ValueNotifier<int> notifier = ValueNotifier<int>(-1);
  int sink = 0;
  final Stopwatch stopwatch = Stopwatch()..start();
  for (int i = 0; i < _iterations; i++) {
    notifier.value = i;
    sink ^= notifier.value;
  }
  stopwatch.stop();
  notifier.dispose();
  return sink == -1 ? -1 : stopwatch.elapsedMicroseconds;
}

int _timeObservable() {
  final Observable<int> observable = Observable<int>(-1);
  int sink = 0;
  final Stopwatch stopwatch = Stopwatch()..start();
  for (int i = 0; i < _iterations; i++) {
    observable.value = i;
    sink ^= observable.value;
  }
  stopwatch.stop();
  observable.close();
  return sink == -1 ? -1 : stopwatch.elapsedMicroseconds;
}

int _timePlainListAddAll(List<int> values) {
  final Stopwatch stopwatch = Stopwatch()..start();
  for (int i = 0; i < 500; i++) {
    <int>[].addAll(values);
  }
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

int _timeObservableListAddAll(List<int> values) {
  final Stopwatch stopwatch = Stopwatch()..start();
  for (int i = 0; i < 500; i++) {
    final ObservableList<int> list = ObservableList<int>();
    list.addAll(values);
  }
  stopwatch.stop();
  return stopwatch.elapsedMicroseconds;
}

void main() {
  test('Observable scalar overhead remains within a broad relative guard', () {
    // Warm both paths before measuring JIT-compiled code.
    _timeValueNotifier();
    _timeObservable();

    final int baseline = _median(
      List<int>.generate(5, (_) => _timeValueNotifier()),
    );
    final int observed = _median(
      List<int>.generate(5, (_) => _timeObservable()),
    );
    final double ratio = observed / baseline;

    expect(
      ratio,
      lessThan(1000),
      reason:
          'Observable/ValueNotifier median ratio was '
          '${ratio.toStringAsFixed(2)}x. This is a debug-mode catastrophe '
          'guard, not a release-performance target.',
    );
  });

  test('ObservableList.addAll remains within a broad relative guard', () {
    final List<int> values = List<int>.generate(1000, (int i) => i);
    _timePlainListAddAll(values);
    _timeObservableListAddAll(values);

    final int baseline = _median(
      List<int>.generate(5, (_) => _timePlainListAddAll(values)),
    );
    final int observed = _median(
      List<int>.generate(5, (_) => _timeObservableListAddAll(values)),
    );
    final double ratio = observed / baseline;

    expect(
      ratio,
      lessThan(20),
      reason:
          'ObservableList/List addAll median ratio was '
          '${ratio.toStringAsFixed(2)}x',
    );
  });
}
