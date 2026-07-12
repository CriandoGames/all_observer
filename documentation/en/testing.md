🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md) | 🇺🇸 English

# Testing

`Observable`, `Computed`, and every worker (`ever`/`once`/`debounce`/
`interval`) are plain Dart objects — no `Provider`/`Bloc`/DI wrapper, no
mocking framework, no code generation. They test the way any Dart object
does: construct it, mutate it, assert on it, with `flutter_test` out of the
box. Every example on this page is a real test that runs in CI, living
under
[`example/test/`](https://github.com/CriandoGames/all_observer/tree/main/example/test)
— none of the snippets below are illustrative pseudocode.

## Widget tests

The basic shape: `pumpWidget` the widget under test, mutate the observable
it reads, `pump()`, assert. No wrapper/scope is required beyond whatever
Material shell your widgets themselves need — unlike `Provider`/`Bloc`,
there's no `ChangeNotifierProvider`/`BlocProvider` to set up first.

```dart
final CounterController controller = CounterController();
addTearDown(controller.dispose);

await tester.pumpWidget(
  MaterialApp(home: Scaffold(body: CounterDemo(controller: controller))),
);
expect(find.text('Count: 0'), findsOneWidget);

controller.increment();
await tester.pump(); // <- required: see the callout below
expect(find.text('Count: 1'), findsOneWidget);
```

Full file:
[`counter_widget_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/counter_widget_test.dart).

> **The `pump()` gotcha.** Assigning a new value never repaints anything by
> itself. `Observer` coalesces its rebuild into the next frame, exactly like
> `ValueListenableBuilder` — you must `await tester.pump()` (or
> `pumpAndSettle()`) after a mutation before asserting on the widget tree.

## Unit tests (pure Dart)

Controller/business-logic tests need no Flutter binding at all: no
`testWidgets`, no `pumpWidget`. `Observable`/`Computed` are constructed and
read like any other Dart object.

```dart
late CounterController controller;

setUp(() => controller = CounterController());
tearDown(() => controller.dispose());

test('mutating count recomputes the derived Computed value', () {
  controller.increment();
  expect(controller.count.value, 1);
  expect(controller.doubled.value, 2);
});
```

Full file:
[`controller_unit_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/controller_unit_test.dart).
Note the `tearDown` calling `dispose()`/`close()` on every observable the
controller owns — the correct habit to carry into your own tests, mirroring
`State.dispose()` in the real widget.

## Proving granular rebuilds

Rebuild granularity is `all_observer`'s central claim, and it's directly
measurable: give two `Observer`s each a build counter, have them read
different observables, mutate one, and assert only the matching counter
moved.

```dart
final ObservableInt a = 0.obs;
final ObservableInt b = 0.obs;
int buildsA = 0;
int buildsB = 0;
// ... Observer(() { buildsA++; return Text('a:${a.value}'); }) ...
// ... Observer(() { buildsB++; return Text('b:${b.value}'); }) ...

a.value = 1;
await tester.pump();
expect(buildsA, 2); // rebuilt
expect(buildsB, 1); // untouched
```

Full file:
[`observer_granularity_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/observer_granularity_test.dart).
Use this technique whenever you need to verify a refactor didn't
accidentally widen what an `Observer` depends on.

## Testing workers & time

`debounce`/`interval` are tested with `flutter_test`'s virtual clock:
`tester.pump(Duration(...))` advances fake time inside a `testWidgets`
body, so timer-based workers resolve deterministically instead of racing a
real `Duration`. This is the same approach the package's own suite uses
(`test/workers/workers_test.dart`) — no extra `fake_async` dependency
needed to test time-based workers.

```dart
controller.query.setValue('a');
await tester.pump(const Duration(milliseconds: 50));
controller.query.setValue('apr');
expect(controller.searchRuns.value, 1); // still inside the debounce window

await tester.pump(const Duration(milliseconds: 250));
expect(controller.searchRuns.value, 2); // exactly one real search ran
```

Full file:
[`worker_debounce_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/worker_debounce_test.dart).

## Testing async state

`ObservableFuture` is tested by injecting a fake `Future` factory through
the constructor — the same "dependency via constructor" pattern applied to
async work — using a `Completer` you control by hand instead of a real
network/timer delay.

```dart
final Completer<int> completer = Completer<int>();
final FetchController controller = FetchController(
  fetcher: () => completer.future,
);

expect(controller.fetch.value, isA<AsyncLoading<int>>());
completer.complete(42);
await Future<void>.delayed(Duration.zero);
expect(controller.fetch.value, const AsyncData<int>(42));
```

Full file:
[`observable_future_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/observable_future_test.dart).
Because the `Completer` only resolves when the test calls `complete`/
`completeError`, the loading → data and loading → error transitions happen
at an exact point the test controls — nothing here waits on a real timer,
so the test can't flake.

## Strict mode in tests

`ObserverConfig.strictMode` turns two common mistakes — an `Observer` that
reads no observable, and a write to an observable during an `Observer`
build — into a thrown `ObserverError` instead of a console warning a CI log
could scroll past unnoticed.

```dart
setUp(() => ObserverConfig.strictMode = true);
tearDown(ObserverConfig.reset);

testWidgets('an Observer that reads nothing throws', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Observer(() => const Text('x'))));
  expect(tester.takeException(), isA<ObserverError>());
});
```

Full file:
[`strict_mode_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/strict_mode_test.dart).
Always pair `strictMode = true` in `setUp` with `ObserverConfig.reset()` in
`tearDown` so it can't leak into unrelated tests in the same suite.

## Regression tests for effects and graph churn

When changing scheduler internals, keep targeted regression tests around
`effect()` and graph mutation. The package suite covers effects that write
after reading a derived value, self-dispose during the callback, disposal of
the owning `ReactiveScope`, `untracked()` inside `CoreComputed`, graph
changes during dirty checking, and batch-flush exception isolation. Those
tests are intentionally small and should stay active: they protect the
cases most likely to regress when batching, dependency tracking, or the
engine bridge changes.

## Recommended testable architecture

The example app extracts business logic out of `State` and into small
controller classes
([`example/lib/controllers/`](https://github.com/CriandoGames/all_observer/tree/main/example/lib/controllers)),
each constructible with an injectable dependency and a sensible default:

```dart
class FetchController {
  FetchController({Future<int> Function()? fetcher})
    : fetch = ObservableFuture<int>(fetcher ?? _simulateFetch);
  // ...
}
```

The widget creates a default controller internally when none is passed, so
production call sites (`const AsyncDemo()`) stay simple, while a test can
inject a fake:

```dart
AsyncDemo(controller: FetchController(fetcher: () => completer.future));
```

This is the pattern to reach for whenever a widget's state is hard to test
because it's built with no injection point — pull it into a plain Dart
class taking its dependencies through the constructor, with a default that
preserves today's call sites unchanged.

## Checklist

- Call `await tester.pump()` (or `pumpAndSettle()`) after every mutation
  before asserting on the widget tree — a write alone repaints nothing.
- Call `close()`/`dispose()` on every `Observable`/`Computed`/`Worker`/
  controller you own in `tearDown`, mirroring `State.dispose()`.
- Inject async/time dependencies through the constructor (a fetch function,
  a catalog, a debounce `Duration`) instead of hardcoding them, so tests can
  substitute fakes.
- Prefer `flutter_test`'s virtual clock (`tester.pump(duration)`) over real
  `Duration`s for anything debounced/throttled.
- Use a `Completer` to control exactly when an injected `Future` resolves,
  instead of racing a real delay.
- Turn on `ObserverConfig.strictMode` (reset in `tearDown`) in tests/CI to
  catch empty-`Observer` and write-during-build mistakes as failures.
- Business logic (anything not reading `BuildContext`) belongs in a plain
  Dart class you can unit test with no widget binding at all.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Advanced](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md) · Next: [Comparison](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/comparison.md)
