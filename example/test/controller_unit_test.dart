import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer_example/controllers/counter_controller.dart';

/// Pure Dart unit test: only plain `test()` blocks, no `testWidgets`, no
/// `pumpWidget`, no widget binding touched. `flutter_test` is imported only
/// because it's this project's one consistent test entrypoint (it
/// re-exports `package:test`'s `test`/`group`/`expect`) — nothing below
/// actually requires Flutter to run. Business logic tests run without
/// Flutter, because `Observable`/`Computed` are plain Dart objects.
void main() {
  late CounterController controller;

  setUp(() {
    controller = CounterController();
  });

  // Correct practice: close every observable/computed you own once you're
  // done with it, exactly like `State.dispose()` would in the real widget.
  tearDown(() {
    controller.dispose();
  });

  test('doubled starts derived from the initial count', () {
    expect(controller.count.value, 0);
    expect(controller.doubled.value, 0);
  });

  test('mutating count recomputes the derived Computed value', () {
    controller.increment();
    expect(controller.count.value, 1);
    expect(controller.doubled.value, 2);

    controller.increment();
    expect(controller.doubled.value, 4);
  });

  test('reset returns both count and doubled to zero', () {
    controller.increment();
    controller.increment();
    controller.reset();
    expect(controller.count.value, 0);
    expect(controller.doubled.value, 0);
  });

  test('doubled is memoized: only recomputes when count actually changes', () {
    // Reading .value repeatedly without a change must not add new log
    // entries — CounterController.log gets one entry per real recompute.
    controller.doubled.value;
    controller.doubled.value;
    controller.doubled.value;
    expect(controller.computeRuns, 1);

    controller.increment();
    expect(controller.doubled.value, 2);
    expect(controller.computeRuns, 2);
  });
}
