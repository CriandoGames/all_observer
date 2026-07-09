// Regression coverage for a question raised while reading real app logs:
// "[all_observer] ✖ CoreObservable<...> descartado (0 listeners removidos)"
// showed up even though the screen clearly had `Observer` widgets reacting
// to that state. This file proves the two reasons that is *expected*:
//
// 1. An observable read only *indirectly*, through a `Computed`, reports
//    `hasListeners == true` while that engine-graph dependency is alive.
//    The dispose event's `listenerCount`, however, counts only classic
//    `ListenerRegistry` listeners, so `close()` reports 0 after the Computed
//    releases its graph link.
// 2. An observable read *directly* by an `Observer` does show a non-zero
//    count -- but only if you close it while the widget is still mounted.
//    In the normal Flutter lifecycle (widgets dispose top-down before a
//    controller's own `dispose()` runs), the Observer has already removed
//    itself by the time the controller closes the observable, so 0 is the
//    correct, expected number there too.
import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

/// Mirrors a typical screen controller: `isLoading` is only ever read
/// through the derived `statusLabel` Computed, while `count` is read
/// directly by an Observer.
class _DashboardController {
  final Observable<bool> isLoading = Observable<bool>(false, name: 'isLoading');
  final Observable<int> count = Observable<int>(0, name: 'count');

  late final Computed<String> statusLabel = Computed<String>(
    () => isLoading.value ? 'carregando' : 'pronto',
    name: 'statusLabel',
  );

  void dispose() {
    statusLabel.close();
    isLoading.close();
    count.close();
  }
}

class _DashboardScreen extends StatelessWidget {
  const _DashboardScreen({required this.controller});

  final _DashboardController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        // Reads `isLoading` only indirectly, through the Computed.
        Observer(() => Text(controller.statusLabel.value), name: 'status'),
        // Reads `count` directly.
        Observer(() => Text('${controller.count.value}'), name: 'count'),
      ],
    );
  }
}

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('dispose "listeners removidos" log', () {
    testWidgets(
      'a Computed counts in hasListeners but not in dispose listenerCount',
      (WidgetTester tester) async {
        final _DashboardController controller = _DashboardController();
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.inspectors.add(recorder);

        await tester.pumpWidget(_app(_DashboardScreen(controller: controller)));
        expect(find.text('pronto'), findsOneWidget);

        // Since Engine v2, hasListeners deliberately includes both classic
        // ListenerRegistry listeners and subscribers linked through the
        // reactive graph.
        expect(controller.isLoading.hasListeners, isTrue);

        // Prove the reactivity still works end-to-end despite that.
        controller.isLoading.value = true;
        await tester.pump();
        expect(find.text('carregando'), findsOneWidget);

        // Unmount the screen the normal way (Observer.dispose runs first).
        await tester.pumpWidget(_app(const SizedBox()));

        // The Observer subscription to statusLabel is gone, but the live
        // Computed keeps its dependency link until it is explicitly closed.
        expect(controller.isLoading.hasListeners, isTrue);

        recorder.clear();
        controller.statusLabel.close();
        expect(controller.isLoading.hasListeners, isFalse);
        controller.isLoading.close();
        controller.count.close();

        final ObservableDisposeEvent isLoadingDispose = recorder.events
            .whereType<ObservableDisposeEvent>()
            .firstWhere((ObservableDisposeEvent e) => e.label.contains('bool'));

        expect(
          isLoadingDispose.listenerCount,
          0,
          reason:
              'listenerCount preserves its classic ListenerRegistry meaning; '
              'the Computed graph link was released separately by close().',
        );
      },
    );

    testWidgets(
      'an observable read directly by an Observer only closes with 0 listeners '
      'after the widget has unmounted -- closing it early shows the real count',
      (WidgetTester tester) async {
        // --- Anti-pattern: dispose while the Observer is still mounted. ---
        final _DashboardController wrongOrder = _DashboardController();
        final RecordingInspector recorderWrong = RecordingInspector();
        ObserverConfig.inspectors.add(recorderWrong);

        await tester.pumpWidget(_app(_DashboardScreen(controller: wrongOrder)));
        expect(wrongOrder.count.hasListeners, isTrue);

        recorderWrong.clear();
        wrongOrder.count.close();

        final ObservableDisposeEvent wrongOrderEvent = recorderWrong.events
            .whereType<ObservableDisposeEvent>()
            .firstWhere((ObservableDisposeEvent e) => e.label.contains('int'));

        expect(
          wrongOrderEvent.listenerCount,
          1,
          reason:
              'the Observer is still mounted and still subscribed -- this '
              'case must NOT print 0, otherwise a real leak would be '
              'masked by the log.',
        );

        // Clean up the tree without touching the now-closed observable.
        await tester.pumpWidget(_app(const SizedBox()));
        ObserverConfig.inspectors.remove(recorderWrong);

        // --- Correct order: unmount first, dispose second. ---
        final _DashboardController rightOrder = _DashboardController();
        final RecordingInspector recorderRight = RecordingInspector();
        ObserverConfig.inspectors.add(recorderRight);

        await tester.pumpWidget(_app(_DashboardScreen(controller: rightOrder)));
        expect(rightOrder.count.hasListeners, isTrue);

        // Unmounting runs every Observer.dispose(), which removes each one
        // from the registries it was subscribed to.
        await tester.pumpWidget(_app(const SizedBox()));
        expect(rightOrder.count.hasListeners, isFalse);

        recorderRight.clear();
        rightOrder.dispose();

        final ObservableDisposeEvent rightOrderEvent = recorderRight.events
            .whereType<ObservableDisposeEvent>()
            .firstWhere((ObservableDisposeEvent e) => e.label.contains('int'));

        expect(
          rightOrderEvent.listenerCount,
          0,
          reason:
              'by the time controller.dispose() runs, the screen has '
              'already unmounted and every Observer already removed '
              'itself -- 0 is the expected, correct value here.',
        );
      },
    );
  });
}
