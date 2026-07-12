import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer_example/controllers/counter_controller.dart';
import 'package:all_observer_example/demos/counter_demo.dart';

/// Widget test for `CounterDemo` — the most basic all_observer test shape.
///
/// Note what's *absent*: no `ChangeNotifierProvider`, no `BlocProvider`, no
/// wrapper widget around `CounterDemo` beyond the plain `MaterialApp` that
/// any Material widget (the buttons here) needs regardless of state
/// management. `Observable`/`Computed` need no scope to be readable.
void main() {
  testWidgets('increments the count and the derived doubled value', (
    tester,
  ) async {
    // A test-owned controller, injected via the constructor — see
    // documentation/en/testing.md ("Recommended testable architecture").
    final CounterController controller = CounterController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CounterDemo(controller: controller)),
      ),
    );

    expect(find.text('Count: 0'), findsOneWidget);
    expect(find.text('Doubled (Computed): 0'), findsOneWidget);

    controller.increment();
    // Gotcha #1: a value change alone does not repaint anything. `Observer`
    // coalesces its rebuild into the next frame, exactly like
    // `ValueListenableBuilder` — `await tester.pump()` is what actually
    // flushes that frame in a widget test.
    await tester.pump();

    expect(find.text('Count: 1'), findsOneWidget);
    expect(find.text('Doubled (Computed): 2'), findsOneWidget);
  });

  testWidgets('Increment button drives the same controller state', (
    tester,
  ) async {
    final CounterController controller = CounterController();
    addTearDown(controller.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: CounterDemo(controller: controller)),
      ),
    );

    await tester.tap(find.text('Increment'));
    await tester.pump();
    expect(find.text('Count: 1'), findsOneWidget);

    await tester.tap(find.text('Reset'));
    await tester.pump();
    expect(find.text('Count: 0'), findsOneWidget);
  });
}
