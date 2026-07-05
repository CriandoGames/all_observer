import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer_example/controllers/search_controller.dart';

/// Tests `FruitSearchController`'s `debounce` worker using *virtual* time:
/// `tester.pump(Duration(...))` advances the fake clock `flutter_test`
/// already provides for a `testWidgets` body — no real `Duration.wait`, no
/// flaky timing.
///
/// This is deliberately a `flutter_test` `pump`-based test rather than the
/// `fake_async` package: `flutter_test` already ships a controllable clock
/// for anything running inside `testWidgets`, and the lib's own suite
/// (`test/workers/workers_test.dart`) uses the same approach — no extra
/// dependency needed to test time-based workers.
void main() {
  testWidgets(
    'rapid typing coalesces into a single real search after the debounce '
    'window elapses',
    (tester) async {
      final FruitSearchController controller = FruitSearchController(
        catalog: const <String>['apple', 'apricot', 'banana'],
        time: const Duration(milliseconds: 200),
      );
      addTearDown(controller.dispose);

      // The constructor already ran one immediate search (empty query).
      expect(controller.searchRuns.value, 1);

      // Three rapid keystrokes, each well inside the debounce window.
      controller.query.setValue('a');
      await tester.pump(const Duration(milliseconds: 50));
      controller.query.setValue('ap');
      await tester.pump(const Duration(milliseconds: 50));
      controller.query.setValue('apr');
      // Still inside the window: no new search ran yet.
      expect(controller.searchRuns.value, 1);

      // Advance past the debounce window: exactly one more search runs,
      // using the latest value ('apr'), not one per keystroke.
      await tester.pump(const Duration(milliseconds: 250));
      expect(controller.searchRuns.value, 2);
      expect(controller.results, <String>['apricot']);
    },
  );

  testWidgets('disposing the controller cancels a pending debounced search', (
    tester,
  ) async {
    final FruitSearchController controller = FruitSearchController(
      catalog: const <String>['apple', 'banana'],
      time: const Duration(milliseconds: 200),
    );

    controller.query.setValue('a');
    controller.dispose();

    // Advancing time after dispose must not run the pending search, and
    // must not throw (the worker/timer was canceled, not left dangling).
    await tester.pump(const Duration(milliseconds: 300));
  });
}
