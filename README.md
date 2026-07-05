# all_observer

🇧🇷 [Leia em Português](README.pt-BR.md)

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
<a href="https://pub.dev/packages/all_observer/score"><img src="https://img.shields.io/pub/points/all_observer?label=pub%20points" alt="pub points"></a>
 <img src="https://img.shields.io/badge/tests-225-brightgreen" alt="225 tests"> <!-- update when adding tests -->

Reactive state for Flutter, zero dependencies. `Observable` values plus an
auto-tracking `Observer` widget — a small, safe, dependency-free core for
apps that want reactivity without a full state-management framework.

## Why `all_observer`

- **Zero dependencies.** The whole reactive core — tracking, notification,
  collections, workers — is built on `Dart`/`Flutter` alone. No `Stream`,
  no code generation, no external package to keep in sync with your
  Flutter version.
- **No boilerplate.** No providers to register, no context to wire up, no
  base classes to extend. `final count = 0.obs;` plus `Observer(() =>
  ...)` is a complete, working reactive pair.
- **Granular by construction.** Dependencies are discovered by *reading*
  `.value` during a build, not declared up front, so an `Observer` only
  rebuilds for what it actually reads — including conditional branches
  (`if (a) read x else read y`), which are re-evaluated correctly on every
  build.
- **Safe by default.** Rebuilds guard against unmounted widgets, a
  synchronous update cycle (A → B → A) stops instead of overflowing the
  stack, an exception inside one listener never stops the others, and
  every misuse case (empty `Observer`, write during build, write after
  `close()`) warns instead of crashing your app — with an opt-in
  `strictMode` that turns those same warnings into hard failures for CI.
- **Interoperable, not a walled garden.** `Observable<T>` *is* a
  `ValueListenable<T>`, so it drops straight into `ValueListenableBuilder`,
  `AnimatedBuilder`, `Listenable.merge`, or any existing Flutter API that
  already understands that interface.

### When to reach for it

Small to medium apps and features that want local/global reactive state
— counters, form fields, loading flags, a reactive list/cache, a computed
summary — without adopting a full architecture (BLoC-style event/state
plumbing, code-generated providers, etc.). It also works well *alongside*
a larger architecture, as the reactive primitive under a view-model or
controller class.

### When something else may fit better

If you need dependency injection, route-based state scoping, or
compile-time-checked provider graphs, a dedicated DI/state framework will
give you more structure than this package intentionally provides.
`all_observer` has no opinion on where your state *lives* — only on how it
*notifies* — so it composes with those frameworks rather than replacing
them (e.g. wrap an `Observable` inside a provider/service you already
manage).

## Quick start (30 seconds)

```dart
import 'package:all_observer/all_observer.dart';

final count = 0.obs; // ObservableInt

Observer(() => Text('${count.value}'));

count.value++; // rebuilds the Text above, and only that widget
```

Create observables from any type with `.obs`: `0.obs`, `'hi'.obs`,
`false.obs`, `9.99.obs`, `<String>[].obs`, or wrap a custom type with
`Observable<User?>(null, name: 'user')`. Read `.value` inside an `Observer`
builder and the widget rebuilds automatically whenever it changes —
dependencies are re-discovered on every build, so conditional reads work
out of the box.

## `ValueListenable` interop

Every `Observable<T>` implements `ValueListenable<T>`, so it plugs directly
into anything that already speaks that interface — no adapter needed:

```dart
ValueListenableBuilder<int>(
  valueListenable: count, // an Observable<int> works here directly
  builder: (context, value, _) => Text('$value'),
);

AnimatedBuilder(animation: Listenable.merge([count, otherObservable]), ...);
```

## Derived values with `Computed`

```dart
final firstName = 'Carlos'.obs;
final lastName = 'Castro'.obs;
final fullName = Computed(() => '${firstName.value} ${lastName.value}');

Observer(() => Text(fullName.value)); // recomputes only when needed
```

`Computed<T>` is lazy (never runs before the first read), memoized
(cached until a dependency notifies), reuses the same tracking mechanism
as `Observer` (so conditional/dynamic dependencies work the same way),
and only notifies its own listeners when the recomputed value actually
differs from the previous one. Call `close()` to unsubscribe from all
current dependencies.

For a narrower derived value from a single `Observable`, `select` is sugar
over the same pattern: `user.select((u) => u.name)` is exactly
`Computed(() => user.value.name)`. The caller owns and must `close()` the
returned `Computed`.

### Custom `equals` on `Computed`

```dart
final fahrenheit = Computed<double>(
  () => celsius.value * 9 / 5 + 32,
  equals: (a, b) => (a - b).abs() < 0.01,
);
```

Like `Observable`, `Computed` accepts an `equals` override to decide
whether a recomputed value actually changed and should notify — useful for
floating-point tolerances or partial-field comparisons.

### Diamond dependency graphs and `batch`

A "diamond" is two `Computed`s both derived from the same source, with a
third depending on both. Wrap the writes that feed such a graph in
`Observable.batch()`: the recompute of any `Computed` in the graph is
deferred until every write in the batch has settled, so it recomputes at
most once, always from fully consistent upstream values. See "Known
limitations" below for what happens without `batch`.

## Coalescing writes with `Observable.batch`

```dart
Observable.batch(() {
  firstName.value = 'Carlos';
  lastName.value = 'Castro';
  age.value = 30;
}); // manual listen()/ever() listeners fire exactly once, at the end
```

Writes still apply immediately and consistently inside the callback —
only the *notification* to manual subscribers (`listen`, `ever`, etc.) is
deferred and deduplicated. An `Observer` widget already coalesces
multiple dependency changes into a single rebuild per frame on its own,
so `batch()` mainly matters for manual subscriptions. Nested `batch()`
calls are supported; if the callback throws, the pending notifications
built up so far are discarded and the exception propagates normally.

## Custom equality with `equals`

```dart
final price = Observable<double>(
  9.99,
  equals: (a, b) => (a - b).abs() < 0.01,
);
```

By default, a write only notifies when the new value differs from the
current one via `==`. Pass `equals` to use a different comparison — for
example, a tolerance for floating-point values, or comparing only part of
a larger object.

## Reactive collections

```dart
final items = <String>[].obs; // ObservableList<String>

Observer(() => Text('${items.length} items'));

items.add('one');           // notifies once
items.addAll(['two', 'three']); // still notifies once, not three times
items.removeWhere((e) => e == 'two'); // once, and only if something matched
```

`ObservableList`/`ObservableMap`/`ObservableSet` behave like their
built-in counterparts (`ListBase`/`MapBase`/`SetBase`) for every read —
`length`, `[]`, `contains`, iteration — while every mutating member
notifies **at most once per call**, never once per element. A no-op
mutation (adding a `Set` element that's already there, `removeWhere` that
matches nothing, assigning an identical value to an existing map key)
notifies zero times.

## Async values with `ObservableFuture`

```dart
final userFuture = ObservableFuture<User>(() => api.fetchUser(id));

Observer(() => userFuture.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (user) => Text(user.name),
  error: (error, stackTrace) => Text('Error: $error'),
));

userFuture.refresh(); // re-runs the future, e.g. for pull-to-refresh
```

`ObservableFuture<T>` is an `Observable<AsyncState<T>>` that runs a
`Future<T> Function()` and tracks its loading/data/error lifecycle
automatically (`autoStart: true` by default; pass `false` and call `run()`
manually otherwise). `AsyncLoading.previousData` carries the last known
value while a `refresh()` is in flight, for stale-while-loading UIs. Every
`run()`/`refresh()` call is race-safe: if a newer call starts before an
older one resolves, the older result (success or error) is discarded when
it eventually arrives, and any in-flight result is also discarded if
`close()` was called meanwhile.

## Beyond `Observer`: effects, streams, inspection, and lifecycle helpers

A set of smaller, independent building blocks — each optional, none
changing the core reactive graph.

### Standalone reactivity with `effect()`

```dart
final dispose = effect(() {
  print('count is now ${count.value}');
});
// ...
dispose(); // stop reacting
```

`effect()` runs immediately and again whenever any observable it reads
changes — the same auto-tracking `Observer` uses, without a widget. Useful
outside the widget tree (a controller class, a background listener).

### Escape hatches: `untracked()`, `peek()`, `previousValue`

```dart
final result = untracked(() => a.value + b.value); // read without tracking
final current = counter.peek(); // read without tracking, shorter form
final before = counter.previousValue; // value right before the last change
```

`untracked()` reads observables inside its callback without registering
them as dependencies of whatever `Observer`/`Computed`/`effect()` is
currently tracking — useful for a one-off read that shouldn't cause a
rebuild on its own. `Observable.peek()` is sugar for the same thing on a
single value; `previousValue` looks at the value from before the most
recent update, with no extra bookkeeping to opt into.

### Pluggable observability with `ObserverInspector`

```dart
final recorder = RecordingInspector();
ObserverConfig.inspectors.add(recorder);
// ... later
for (final event in recorder.events) {
  print(event); // ObservableCreateEvent, ObservableUpdateEvent, ...
}
```

Every creation/update/dispose/tracking/warning/effect-run event is exposed
through the `ObserverInspector` interface, not just printed to the console.
The classic colored terminal output is itself a formal implementation —
`ConsoleInspector` — registered internally by default; `RecordingInspector`
ships as an in-memory audit trail. Write your own to forward events to
analytics, a custom log sink, or a debug overlay — an exception thrown by
one inspector never blocks the others.

### `ObservableStream`, the `Stream` counterpart of `ObservableFuture`

```dart
final ticks = ObservableStream<int>(
  () => Stream.periodic(const Duration(seconds: 1), (i) => i),
);
Observer(() => ticks.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (n) => Text('$n'),
  error: (error, stackTrace) => Text('Error: $error'),
));
```

Same `AsyncState`/loading-data-error contract as `ObservableFuture`, driven
by a `Stream` instead: every event becomes `AsyncData`, a stream error
becomes `AsyncError`, and `refresh()` cancels the current subscription and
starts a fresh one — race-safe via the same generation-counter guard.

### `ObserverStateMixin`, for side effects tied to a `State`'s lifetime

```dart
class _MyPageState extends State<MyPage> with ObserverStateMixin {
  @override
  void initState() {
    super.initState();
    autorun(() {
      if (session.value.isExpired) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }
}
```

`autorun` is `effect()` auto-disposed with the `State`; `autoDispose` takes
any `Disposer` (a subscription's `.cancel`, a `Computed`'s `.close`, ...).
This is for side effects that don't belong in `build()` — navigation,
snackbars, driving an `AnimationController` — not a replacement for
`Observer`.

### Optional persistence with `ObservableStore`

```dart
final theme = Observable<String>('light');
final stop = theme.persistWith(myThemeStore); // myThemeStore: ObservableStore<String>
// ...
stop(); // stop persisting; `theme` keeps working normally
```

`ObservableStore<T>` is a three-method (`read`/`write`/`delete`) interface
with no implementation shipped here — `all_observer` stays dependency-free.
A bridge package (e.g. [`all_box`](https://pub.dev/packages/all_box)) can
implement it against real storage; `persistWith` restores once on binding
and writes back on every subsequent change.

### Bounded undo/redo with `ObservableHistory`

```dart
final text = Observable<String>('');
final history = text.withHistory(limit: 50);
text.value = 'hello';
text.value = 'hello world';
history.undo(); // text.value == 'hello'
history.undo(); // text.value == ''
history.redo(); // text.value == 'hello'
history.dispose();
```

Records every value change, skips changes made by `undo()`/`redo()`
themselves (so redoing after undoing restores the exact value, instead of
creating a new branch), and drops the oldest entries once `limit` is
exceeded.

### `package:all_observer/core.dart` — the pure-Dart engine, without Flutter

```dart
import 'package:all_observer/core.dart';

final counter = CoreObservable<int>(0);
counter.addListener(() => print('now ${counter.value}'));
counter.value = 1;
```

The dependency tracker, listener registry, batch/flush engine, and
observability types have **zero import of `package:flutter`** and are
re-exported through this separate entry point — usable from a CLI tool, a
server, or a background isolate, not just a Flutter app. `Observable`/
`Computed` (from `all_observer.dart`) are thin `ValueListenable` + console-
logging wrappers over `CoreObservable`/`CoreComputed` — same engine, same
behavior, Flutter added on top.

## Fine-grained rebuilds with `Observer.withChild`

```dart
Observer.withChild(
  builder: (context, child) => Row(
    children: [Text('${count.value}'), child],
  ),
  child: const ExpensiveStaticWidget(),
);
```

A static child subtree, a common technique for avoiding rebuilds of
expensive widgets that don't depend on any observable: `child` is built
once and passed back into `builder` on every rebuild instead of being
reconstructed.

## `setValue`, an unambiguous way to assign `null`

```dart
final name = Observable<String?>('Carlos');
name.setValue(null); // assigns null and notifies
```

`call()` treats a `null` argument as "no argument" (to support the
no-argument `observable()` read form), so `observable(null)` reads instead
of assigning. `setValue(newValue)` is equivalent to `value = newValue` and
assigns `null` unambiguously; it is also handy as a tear-off (e.g. directly
as an `onChanged` callback).

## Local, self-contained state with `ObserverValue`

```dart
ObserverValue<ObservableInt>(
  (data) => ElevatedButton(
    onPressed: () => data.value++,
    child: Text('${data.value}'),
  ),
  0.obs,
);
```

A thin convenience over `Observer` for state that's created and consumed
right where it's used: pass the observable in, get it back inside
`builder` on every rebuild — no separate variable to declare above the
widget, no explicit `Observer(() => ...)` wrapping.

## Side effects with workers

```dart
final query = ''.obs;
final isLoggedIn = false.obs;
final count = 0.obs;
final scrollOffset = 0.0.obs;

// Runs 400ms after the last change — perfect for search-as-you-type.
final debounceWorker = debounce(query, (String value) {
  runSearch(value);
}, time: const Duration(milliseconds: 400));

// Runs once, then disposes itself automatically.
once(isLoggedIn, (bool value) {
  if (value) analytics.logLogin();
});

// Runs on every change, like a manual listener with a friendlier name.
final everWorker = ever(count, (int value) => print('count is now $value'));

// Runs at most once per `time`, immediately on the first change.
final intervalWorker = interval(scrollOffset, (double value) {
  saveScrollPosition(value);
}, time: const Duration(seconds: 1));

// Dispose whichever ones you keep a reference to when you're done:
Workers([debounceWorker, everWorker, intervalWorker]).dispose();
```

Workers are the recommended way to run non-widget side effects (network
calls, analytics, persistence) off an observable change, instead of
sprinkling `addListener` calls by hand. `once` disposes itself after
firing; `debounce`/`interval` cancel their internal `Timer` on `dispose()`
so nothing fires after you're done with them.

## Colored debug logs

Enable `ObserverConfig.logging = true` during development to see reactivity
happen in your terminal, color-coded by event type:

| Event | Color |
|---|---|
| ✚ creation | green |
| ↻ value update | cyan (values in magenta) |
| 👁 Observer tracking | blue |
| ✖ dispose | gray |
| ⚠ misuse warning | bold yellow |

```
[all_observer] ✚ Observable<int>(count) criado → 0
[all_observer] ↻ Observable<int>(count): 0 → 1
[all_observer] 👁 Observer(contador) rastreando: [count, isLoading]
[all_observer] ✖ Observable<int>(count) descartado (2 listeners removidos)
```

Set `ObserverConfig.useColors = false` on terminals without ANSI support.
Misuse warnings (an `Observer` that reads nothing, a write after `close()`,
a write during build, a probable listener leak) are on by default via
`ObserverConfig.warnings` and never crash the app — set `strictMode = true`
to turn the "empty Observer" case into an exception for CI/tests.

## Design decisions

Rebuilds are guarded against already-unmounted widgets: the internal
callback checks `mounted` before scheduling work, and defers to the next
frame instead of a bare microtask when a change happens mid-build. Nested
reactive builders are supported correctly through a stack-based dependency
tracker, rather than a single mutable "current context" that nested
tracking could clobber. Notification semantics are a single, predictable
rule — a write only notifies if the new value differs from the current one
— with no special-casing for first assignment; mutable objects changed in
place can force a notification via `refresh()`. Equality (`==`/`hashCode`)
is never overridden on the reactive wrapper, so comparisons always mean
what they say: compare `.value` explicitly. The core has no `Stream` or
`StreamController` inside it — `listen()` is built directly on top of a
lightweight listener registry, keeping the reactive core small. And rather
than throwing on likely mistakes, the package favors friendly, non-fatal
warnings by default, with an opt-in strict mode for teams that want hard
failures in CI.

## More

- `ObservableList`, `ObservableMap`, `ObservableSet`: reactive collections; reading any member tracks it, mutating any member notifies exactly once per call (bulk operations like `addAll`/`removeWhere`/`retainWhere` never notify per element).
- `Computed<T>`: lazy, memoized derived values built on the same dependency tracker as `Observer`, with an optional custom `equals` and batch-aware diamond-glitch mitigation.
- `ObservableFuture<T>` / `ObservableStream<T>` / `AsyncState<T>` (aliased `AsyncValue<T>`): race-safe async loading/data/error state built on `Observable`, driven by a `Future` or a `Stream`.
- `effect()` / `untracked()` / `Observable.peek()` / `Observable.previousValue`: standalone reactivity and tracking escape hatches.
- `ObserverInspector` / `ConsoleInspector` / `RecordingInspector`: pluggable observability for every lifecycle/update/warning event.
- `ObserverStateMixin`: auto-disposed `effect()`s and manual subscriptions tied to a `State`'s lifetime.
- `ObservableStore<T>` / `Observable.persistWith`: optional persistence integration point (e.g. for `all_box`), no dependency added.
- `ObservableHistory<T>` / `Observable.withHistory`: bounded undo/redo for any `Observable`.
- `package:all_observer/core.dart`: the pure-Dart engine (`CoreObservable`, `CoreComputed`, `DependencyTracker`, ...), zero `package:flutter` import, usable outside Flutter.
- `Observable.batch`: coalesces multiple writes into one notification per changed observable, for manual subscribers.
- `Observer.withChild`: rebuilds only the builder-owned part of a subtree, reusing a static `child` across rebuilds.
- `Observable.select`: sugar for a narrower `Computed` derived from one `Observable`.
- `ObserverValue<T>`: local, self-contained reactive state without managing an observable's lifecycle separately.
- `ever`, `once`, `debounce`, `interval`: workers for side effects driven by observable changes.
- A synchronous update cycle (A's listener writes B, B's listener writes A, ...) is stopped after a bounded notification depth with a descriptive error, instead of a raw stack overflow; an exception thrown inside one listener never stops the other listeners of the same observable from running.
- See `/example` for a runnable demo (counter, reactive list, worker, debug-log toggle), and `/benchmark` for manual Stopwatch-based microbenchmarks.

## How `all_observer` compares

A factual, non-marketing comparison against other Flutter/Dart reactivity
approaches — what each one requires that `all_observer` doesn't, and vice
versa. None of these are "bad"; they solve for different priorities.

| | `all_observer` | GetX | Riverpod | MobX | flutter_hooks |
|---|---|---|---|---|---|
| External dependencies | **Zero** | Zero (itself is all-in-one) | `riverpod`, often `flutter_riverpod`/`riverpod_generator` | `mobx`, `mobx_codegen`, `build_runner` | `flutter_hooks` |
| Code generation | None | None | Optional (`riverpod_generator`), common in practice | Required (`build_runner`) for `@observable`/`@computed`/`@action` | None |
| Scope | Reactive values + widget rebuilding only | State + routing + DI + snackbars/dialogs (a full framework) | State + DI (provider graph), no routing/UI helpers | Reactive values + actions/reactions, no DI/routing | Widget-local composable state/lifecycle, no cross-widget store |
| Dependency tracking | Auto (read `.value` during build/`effect()`/`Computed`) | Auto, via `Obx`/`GetX` reading `.value`/`.obs` | Auto, via `ref.watch` inside a `Provider`/`Notifier` | Auto, via `Observer`/reactions reading `@observable` fields | N/A (hooks are widget-local, not a dependency graph) |
| Diamond-dependency glitches | Prevented by design (`ADR-0001`/`ADR-0002` in `ARCHITECTURE.md`) | Not a documented guarantee | N/A (providers don't form a `Computed`-chain graph the same way) | Prevented by MobX's own reactive core | N/A |
| `ValueListenable` interop | Direct — `Observable<T>` *is* one | No | No | No | No |
| Escape hatches | `untracked()`, `.peek()`, `.previousValue` | `.value` reads outside `Obx` already untracked | `ref.read` (untracked read) | `mobx.untracked` | N/A |
| Observability | Pluggable `ObserverInspector` (`ConsoleInspector`, `RecordingInspector`, or your own) | Console logging via `Get.log` | `ProviderObserver` | MobX dev-tools / Spy API | N/A |
| Usable outside Flutter | Yes — `package:all_observer/core.dart`, zero Flutter import | No | Yes (`riverpod` core has a non-Flutter variant) | Yes (`mobx` core is pure Dart) | No (Flutter-only, by design) |
| Failure mode for misuse | Friendly warning by default, opt-in `strictMode` throws | Varies by API surface | Compile-time-checked provider graph catches some classes of mistake earlier | Runtime warnings in dev mode | Compile-time (hook rules enforced by lint) |

### Why choose `all_observer`

Reach for it when you want reactive state and nothing else: no DI
container to learn, no routing convention to adopt, no code generator in
your build pipeline, and no risk of a transitive dependency going stale or
unmaintained, because there isn't one. `final count = 0.obs;` plus
`Observer(() => Text('${count.value}'))` is the entire mental model — the
same primitive scales from a single counter to a `Computed` graph, race
-safe async state, and pluggable observability, without switching
vocabulary partway through. It composes with (rather than replaces) GetX's
routing/DI, Riverpod's provider graph, or a hand-rolled controller class,
since `all_observer` has no opinion on where state *lives* — only on how
it *notifies*.

Reach for something else when you specifically need what that something
else specializes in: GetX's all-in-one routing+DI+state if you want one
framework for everything; Riverpod if you want a compile-time-checked DI
graph and don't mind the provider-declaration ceremony; MobX if you're
already invested in its action/reaction vocabulary and codegen step;
`flutter_hooks` if your state is genuinely widget-local and you want
`useState`/`useEffect`-style composition instead of a standalone value.

## Migrating from other reactive state solutions

`all_observer` covers the same core concepts most reactive state
approaches do, under its own names. This is a concept-by-concept map, not
a name-for-name port of any specific library:

| Concept | `all_observer` |
|---|---|
| Rx-style reactive value | `Observable<T>` (`.obs` to create one) |
| Reactive builder widget, auto-tracking dependencies | `Observer` |
| Derived/computed reactive value | `Computed<T>` |
| Side-effect helpers on value change (`ever`/`once`/`debounce`/`interval`) | Same names: `ever`, `once`, `debounce`, `interval` |
| Async loading/data/error state | `ObservableFuture<T>` / `AsyncState<T>` |
| Coalesced/transactional writes | `Observable.batch(() { ... })` |
| Dispose / teardown | `close()` on every `Observable`/`Computed`/collection |

What has **no** equivalent here, by design — `all_observer` only handles
*reactivity*, not app architecture:

- **Routing / navigation**: use Flutter's own `Navigator`/`Router`, or a
  dedicated routing package.
- **Snackbars / dialogs / overlays**: use Flutter's own `ScaffoldMessenger`,
  `showDialog`, `showModalBottomSheet`, etc. directly — `all_observer` has
  no UI-side-effect layer to hook into these.
- **Dependency injection / service location**: bring your own DI solution
  (a simple constructor-passed singleton, an `InheritedWidget`, or a
  dedicated DI package) and store `Observable`s inside the services/
  controllers it manages — `all_observer` has no opinion on where state
  *lives*, only on how it *notifies*.

## Known limitations

- **`Observable.batch()` is a performance optimization, not a consistency
  requirement.** Since v1.2.0 every write — even a standalone
  `observable.value = x` outside any explicit `batch()` — is automatically
  routed through the same two-phase flush that `batch()` uses. Diamond
  dependency graphs (`Computed` A and B both derived from source S, `Computed`
  C depending on A and B) always recompute exactly once, always from fully
  settled upstream values — no glitch, no batch required. Wrapping multiple
  writes in `batch()` remains useful to coalesce notifications: all writes
  in the callback are committed first, then listeners are notified once per
  changed observable, instead of once per write.
- **`Computed` stays subscribed after its first read, until `close()`.**
  Reading `.value` (or attaching a listener) makes a `Computed` subscribe
  to its current dependencies indefinitely — it does not unsubscribe
  itself just because nobody is listening anymore. Call `close()` once
  you're done with a `Computed` you created manually (short-lived ones,
  e.g. from `select`, are easy to forget).
- **Single-isolate confinement.** Like the rest of Dart, every
  `Observable`/`Computed`/collection is confined to the isolate that
  created it; there is no cross-isolate synchronization. Use
  `SendPort`/`ReceivePort` or `compute` to move data between isolates and
  write back to the observable on its own isolate.

## Other packages by us

`all_observer` is part of a small family of zero/low-dependency Dart &
Flutter packages published under the
[`opensource.tatamemaster.com.br`](https://pub.dev/publishers/opensource.tatamemaster.com.br/packages)
verified publisher:

- [`all_validations_br`](https://pub.dev/packages/all_validations_br) —
  Brazilian document validation (CPF, CNPJ, CNH, PIX), 23 input
  formatters/masks, and pure-Dart utilities (JWT, UUID, currency,
  ChaCha20-Poly1305/AES encryption).
- [`all_box`](https://pub.dev/packages/all_box) — synchronous, lightweight
  key-value storage for Flutter with crash-safe writes (write-ahead +
  atomic rename) and a pure-Flutter reactive layer.
- [`all_image_compress`](https://pub.dev/packages/all_image_compress) —
  pure-Dart image compression (JPEG, PNG, GIF, BMP, TIFF, WebP), running
  in isolates to avoid UI jank, no native code required.

## 👥 Contributors

[![Contributors](https://contrib.rocks/image?repo=CriandoGames/all_observer)](https://github.com/CriandoGames/all_observer/graphs/contributors)

Made with [contrib.rocks](https://contrib.rocks).

Contributions are welcome! Read [CONTRIBUTING.md](CONTRIBUTING.md) to get
started.

---

Issues and pull requests are welcome at the
[GitHub repository](https://github.com/CriandoGames/all_observer).
