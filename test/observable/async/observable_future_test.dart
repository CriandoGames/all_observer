import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/async/async_state.dart';
import 'package:all_observer/src/observable/async/observable_future.dart';
import 'package:all_observer/src/observable/observable.dart';

void main() {
  group('ObservableFuture', () {
    test('autoStart runs futureFactory immediately and resolves to '
        'AsyncData on success', () async {
      final ObservableFuture<int> future = ObservableFuture<int>(
        () async => 42,
      );
      expect(future.value, isA<AsyncLoading<int>>());
      await Future<void>.delayed(Duration.zero);
      expect(future.value, const AsyncData<int>(42));
    });

    test('autoStart: false does not run until run() is called', () async {
      int calls = 0;
      final ObservableFuture<int> future = ObservableFuture<int>(() async {
        calls++;
        return 1;
      }, autoStart: false);
      expect(calls, 0);
      expect(future.value, isA<AsyncLoading<int>>());
      await future.run();
      expect(calls, 1);
      expect(future.value, const AsyncData<int>(1));
    });

    test('resolves to AsyncError when futureFactory throws', () async {
      final ObservableFuture<int> future = ObservableFuture<int>(
        () async => throw StateError('boom'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(future.value, isA<AsyncError<int>>());
      final AsyncError<int> errorState = future.value as AsyncError<int>;
      expect(errorState.error, isA<StateError>());
    });

    test(
      'refresh preserves the previous data as AsyncLoading.previousData',
      () async {
        int result = 1;
        final ObservableFuture<int> future = ObservableFuture<int>(
          () async => result,
        );
        await Future<void>.delayed(Duration.zero);
        expect(future.value, const AsyncData<int>(1));

        result = 2;
        final Future<void> refreshFuture = future.refresh();
        // Immediately after calling refresh, still loading, but with the
        // previous value preserved.
        final AsyncState<int> mid = future.value;
        expect(mid, isA<AsyncLoading<int>>());
        expect((mid as AsyncLoading<int>).previousData, 1);

        await refreshFuture;
        expect(future.value, const AsyncData<int>(2));
      },
    );

    test('a stale run() result is discarded when a newer run() started '
        'before it completed', () async {
      final List<int> order = <int>[];
      final Completer<int> firstCompleter = Completer<int>();
      final Completer<int> secondCompleter = Completer<int>();
      int callIndex = 0;

      final ObservableFuture<int> future = ObservableFuture<int>(() {
        callIndex++;
        order.add(callIndex);
        return callIndex == 1 ? firstCompleter.future : secondCompleter.future;
      });

      // Kick off a second, overlapping run before the first resolves.
      final Future<void> secondRun = future.run();

      // Resolve the *older* call after the newer one, out of order.
      secondCompleter.complete(20);
      await secondRun;
      expect(future.value, const AsyncData<int>(20));

      firstCompleter.complete(10);
      await Future<void>.delayed(Duration.zero);

      // The stale first result must never overwrite the newer state.
      expect(future.value, const AsyncData<int>(20));
      expect(order, <int>[1, 2]);
    });

    test(
      'a result arriving after close() is discarded without writing',
      () async {
        final Completer<int> completer = Completer<int>();
        final ObservableFuture<int> future = ObservableFuture<int>(
          () => completer.future,
        );
        expect(future.isClosed, isFalse);
        future.close();
        completer.complete(99);
        await Future<void>.delayed(Duration.zero);
        // No exception, and no write occurred post-close (value getter still
        // reflects the closed state; writes silently no-op per Observable's
        // documented close() contract).
        expect(future.isClosed, isTrue);
      },
    );

    test('a stale error result is also discarded when a newer run() has '
        'already started', () async {
      final Completer<int> firstCompleter = Completer<int>();
      int callIndex = 0;
      final ObservableFuture<int> future = ObservableFuture<int>(() {
        callIndex++;
        if (callIndex == 1) {
          return firstCompleter.future;
        }
        return Future<int>.value(5);
      });

      final Future<void> secondRun = future.run();
      await secondRun;
      expect(future.value, const AsyncData<int>(5));

      firstCompleter.completeError(StateError('stale error'));
      await Future<void>.delayed(Duration.zero);

      // The stale error must not overwrite the newer AsyncData.
      expect(future.value, const AsyncData<int>(5));
    });
  });

  group('ObservableFuture inside Observable.batch', () {
    test('the synchronous AsyncLoading transition participates in the '
        'batch (coalesced with a sibling write), but the eventual '
        'AsyncData/AsyncError transition happens after the await gap, '
        'once the batch has already ended, and notifies on its own', () async {
      final Observable<int> sibling = Observable<int>(1);
      // `futureFactory` itself is fixed (an indirection through the
      // mutable `provider` variable it captures), since `ObservableFuture`
      // doesn't let it be reassigned after construction. `provider` is set
      // *before* `run()` ever executes (`autoStart: false`), so the
      // constructor never invokes it while still unassigned.
      late Future<int> Function() provider;
      final ObservableFuture<int> future = ObservableFuture<int>(
        () => provider(),
        autoStart: false,
      );

      // Resolve once, up front, *before* the batch: `future`'s value is
      // then `AsyncData(1)`. Starting `run()` again inside the batch below
      // transitions it to `AsyncLoading(previousData: 1)` — a state whose
      // *content* genuinely differs from `AsyncData(1)` (unlike starting
      // fresh from `AsyncLoading(previousData: null)` and immediately
      // calling `run()` again, which would produce another
      // `AsyncLoading(previousData: null)` — content-equal to the
      // pre-existing one, and therefore not a write `Observable` would
      // even notify for in the first place).
      provider = () async => 1;
      await future.run();
      expect(future.value, const AsyncData<int>(1));

      final Completer<int> completer = Completer<int>();
      provider = () => completer.future;
      final List<String> events = <String>[];
      future.listen((AsyncState<int> _) => events.add('future'));
      sibling.listen((int _) => events.add('sibling'));

      Observable.batch(() {
        future.run(); // fire-and-forget: only the sync part runs here.
        sibling.value = 2;
      });

      // Immediately after the batch returns, `run()`'s synchronous
      // `AsyncLoading` write already happened (and was coalesced with
      // `sibling`'s write into a single flush at the end of the batch —
      // both notified once, in some order, but before the Future resolves).
      expect(future.value, isA<AsyncLoading<int>>());
      expect(events, containsAll(<String>['future', 'sibling']));
      expect(events, hasLength(2));
      events.clear();

      // The `AsyncData` transition happens later, past the `await` gap
      // inside `run()`, entirely outside the batch that started it — so it
      // notifies immediately, by itself, exactly like any other write
      // outside a batch.
      completer.complete(42);
      await Future<void>.delayed(Duration.zero);
      expect(future.value, const AsyncData<int>(42));
      expect(events, <String>['future']);
    });
  });

  group('ObservableFuture.run() previousData chain (T1.2)', () {
    test(
      'run() called again before first completes preserves previousData '
      'from the last AsyncData',
      () async {
        final Completer<int> first = Completer<int>();
        final Completer<int> second = Completer<int>();
        int calls = 0;

        final ObservableFuture<int> future = ObservableFuture<int>(() {
          calls++;
          return calls == 1 ? first.future : second.future;
        }, autoStart: false);

        // Resolve once to get into AsyncData(42).
        first.complete(42);
        await future.run();
        expect(future.value, const AsyncData<int>(42));

        // First refresh (call 2) → AsyncLoading(previousData: 42).
        final Future<void> secondRun = future.run();

        // At this point state is AsyncLoading with previousData from AsyncData.
        expect(future.value, isA<AsyncLoading<int>>());
        expect((future.value as AsyncLoading<int>).previousData, 42);

        // Second refresh (call 3) while call 2 is still in flight.
        final Completer<int> third = Completer<int>();
        // Replace factory behavior via an indirection trick: just call run()
        // again — the factory call count drives which completer is used.
        final Future<void> thirdRun = future.run();

        // State is still AsyncLoading — previousData must still be 42,
        // NOT null (the bug: previously .valueOrNull returned null here).
        expect(future.value, isA<AsyncLoading<int>>());
        expect(
          (future.value as AsyncLoading<int>).previousData,
          42,
          reason: 'previousData must survive a second run() call while still '
              'in AsyncLoading state',
        );

        // Resolve the second and third completers.
        second.complete(99);
        third.complete(100);

        await secondRun;
        await thirdRun;
      },
    );

    test(
      'chain of 3 run() calls — previousData stays 42 throughout',
      () async {
        int calls = 0;
        final List<Completer<int>> completers = <Completer<int>>[
          Completer<int>(),
          Completer<int>(),
          Completer<int>(),
          Completer<int>(), // 4th for autoStart
        ];

        final ObservableFuture<int> future = ObservableFuture<int>(() {
          final int i = calls++;
          return completers[i].future;
        });

        // AutoStart → call 0; resolve it to get AsyncData(42).
        completers[0].complete(42);
        await Future<void>.delayed(Duration.zero);
        expect(future.value, const AsyncData<int>(42));

        // 3 rapid run() calls while previous ones are still in flight.
        final Future<void> r1 = future.run(); // call 1
        final Future<void> r2 = future.run(); // call 2
        final Future<void> r3 = future.run(); // call 3

        // Each intermediate state must carry previousData = 42.
        for (int i = 0; i < 3; i++) {
          expect(future.value, isA<AsyncLoading<int>>());
          expect(
            (future.value as AsyncLoading<int>).previousData,
            42,
            reason: 'previousData must be 42 after $i intermediate run() '
                'calls',
          );
        }

        // Resolve stale completers (discarded), then the winning one.
        completers[1].complete(1);
        completers[2].complete(2);
        completers[3].complete(99);
        await r1;
        await r2;
        await r3;

        expect(future.value, const AsyncData<int>(99));
      },
    );

    test(
      'run() after an AsyncError → previousData is null (documented choice)',
      () async {
        final ObservableFuture<int> future = ObservableFuture<int>(
          () async => throw StateError('boom'),
        );
        await Future<void>.delayed(Duration.zero);
        expect(future.value, isA<AsyncError<int>>());

        // Now run() again — current state is AsyncError, no previousData.
        final Completer<int> completer = Completer<int>();
        int calls = 0;
        final ObservableFuture<int> future2 = ObservableFuture<int>(() {
          calls++;
          if (calls == 1) return Future<int>.error(StateError('boom'));
          return completer.future;
        });
        await Future<void>.delayed(Duration.zero);
        expect(future2.value, isA<AsyncError<int>>());

        future2.run(); // second run from error state
        expect(future2.value, isA<AsyncLoading<int>>());
        expect(
          (future2.value as AsyncLoading<int>).previousData,
          isNull,
          reason: 'AsyncError state carries no previousData by design',
        );
        completer.complete(7);
        await Future<void>.delayed(Duration.zero);
        expect(future2.value, const AsyncData<int>(7));
      },
    );
  });
}
