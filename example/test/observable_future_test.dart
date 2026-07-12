import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';
import 'package:all_observer_example/controllers/fetch_controller.dart';

/// Tests `FetchController`'s `ObservableFuture` with a fake, fully
/// controlled `Future` injected via the constructor — the "dependency via
/// constructor" pattern applied to async work. Because the fake never
/// resolves until the test tells it to (via a `Completer`), the
/// loading -> data and loading -> error transitions are asserted at exact,
/// deterministic points instead of racing a real timer, so this test can
/// never be flaky.
void main() {
  test('transitions from loading to data when the fetch resolves', () async {
    final Completer<int> completer = Completer<int>();
    final FetchController controller = FetchController(
      fetcher: () => completer.future,
    );
    addTearDown(controller.dispose);

    expect(controller.fetch.value, isA<AsyncLoading<int>>());

    completer.complete(42);
    await Future<void>.delayed(Duration.zero);

    expect(controller.fetch.value, const AsyncData<int>(42));
  });

  test('transitions from loading to error when the fetch throws', () async {
    final Completer<int> completer = Completer<int>();
    final FetchController controller = FetchController(
      fetcher: () => completer.future,
    );
    addTearDown(controller.dispose);

    expect(controller.fetch.value, isA<AsyncLoading<int>>());

    completer.completeError(StateError('simulated failure'));
    await Future<void>.delayed(Duration.zero);

    expect(controller.fetch.value, isA<AsyncError<int>>());
    final AsyncError<int> errorState =
        controller.fetch.value as AsyncError<int>;
    expect(errorState.error, isA<StateError>());
  });

  test(
    'retry() preserves the previous data as AsyncLoading.previousData',
    () async {
      int callCount = 0;
      final List<Completer<int>> completers = <Completer<int>>[
        Completer<int>(),
        Completer<int>(),
      ];
      final FetchController controller = FetchController(
        fetcher: () => completers[callCount++].future,
      );
      addTearDown(controller.dispose);

      completers[0].complete(1);
      await Future<void>.delayed(Duration.zero);
      expect(controller.fetch.value, const AsyncData<int>(1));

      final Future<void> retryFuture = controller.retry();
      final AsyncState<int> mid = controller.fetch.value;
      expect(mid, isA<AsyncLoading<int>>());
      expect((mid as AsyncLoading<int>).previousData, 1);

      completers[1].complete(2);
      await retryFuture;
      expect(controller.fetch.value, const AsyncData<int>(2));
    },
  );
}
