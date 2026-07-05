🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md) | 🇺🇸 English

# Advanced

`batch`, diamond dependency graphs, `equals`/`setValue`, logging/`strictMode`,
design decisions, known limitations, testing — plus the smaller optional
building blocks (`effect`, `untracked`, inspectors, lifecycle helpers,
`core.dart`).

## `Observable.batch`

```dart
Observable.batch(() {
  firstName.value = 'Carlos';
  lastName.value = 'Castro';
  age.value = 30;
}); // manual listen()/ever() listeners fire exactly once, at the end
```

Writes still apply immediately and consistently inside the callback — only
the *notification* to manual subscribers (`listen`, `ever`, etc.) is
deferred and deduplicated. An `Observer` widget already coalesces multiple
dependency changes into a single rebuild per frame on its own, so `batch()`
mainly matters for manual subscriptions. Nested `batch()` calls are
supported (only the outermost flushes); if the callback throws, the
pending notifications built up so far are discarded and the exception
propagates normally.

## Diamond dependency graphs

A "diamond" is two `Computed`s both derived from the same source, with a
third depending on both (`a -> b, a -> c, [b, c] -> d`).

Since v1.2.0, `Observable.batch()` is a **performance optimization, not a
consistency requirement**. Every write — even a standalone
`observable.value = x` outside any explicit `batch()` — is automatically
routed through the same two-phase flush that `batch()` uses. Diamond graphs
always recompute exactly once, always from fully settled upstream values —
no glitch, no `batch()` required.

Wrapping multiple writes in `batch()` remains useful to *coalesce*
notifications: all writes in the callback commit first, then listeners are
notified once per changed observable, instead of once per write. See
`ARCHITECTURE.md`'s "two-phase flush" section for the exact mechanism (two
queues drained in fixed-point waves, bounded by `kMaxFlushWaves`).

## `setValue` — an unambiguous way to assign `null`

```dart
final name = Observable<String?>('Carlos');
name.setValue(null); // assigns null and notifies
```

`call()` treats a `null` argument as "no argument" (to support the
no-argument `observable()` read form), so `observable(null)` reads instead
of assigning. `setValue(newValue)` is equivalent to `value = newValue` and
assigns `null` unambiguously; it's also handy as a tear-off (e.g. directly
as an `onChanged` callback).

## Custom `equals`

Both `Observable` and `Computed` accept an `equals` override to decide
whether a write/recompute actually changed and should notify:

```dart
final fahrenheit = Computed<double>(
  () => celsius.value * 9 / 5 + 32,
  equals: (a, b) => (a - b).abs() < 0.01,
);
```

Useful for floating-point tolerances or partial-field comparisons on larger
objects.

## `ObserverConfig`: logging, warnings, `strictMode`

```dart
ObserverConfig.logging = true; // colored terminal output
```

```
[all_observer] ✚ Observable<int>(count) created → 0
[all_observer] ↻ Observable<int>(count): 0 → 1
[all_observer] 👁 Observer(counter) tracking: [count, isLoading]
[all_observer] ✖ Observable<int>(count) disposed (2 listeners removed)
```

| Event | Color |
|---|---|
| ✚ creation | green |
| ↻ value update | cyan (values in magenta) |
| 👁 Observer tracking | blue |
| ✖ dispose | gray |
| ⚠ misuse warning | bold yellow |

- `ObserverConfig.useColors = false` — disable ANSI colors on terminals
  without support.
- `ObserverConfig.logLevel` — `all` (default), `updates`, `lifecycle`, or
  `tracking`, to narrow which categories print.
- `ObserverConfig.warnings` (default `true`) — misuse warnings: an
  `Observer` that reads nothing, a write after `close()`, a write during
  build, a probable listener leak (`listenerLeakThreshold`, default 50).
  Never crashes the app on its own.
- `ObserverConfig.strictMode` (default `false`) — turns the "empty
  Observer" and "write during build" cases into a thrown `ObserverError`
  instead of a warning. Turn this on in CI/tests to catch these mistakes as
  hard failures.
- `ObserverConfig.reset()` — resets every setting to its default; useful
  between tests.

All logging is debug-only: in release builds (`kReleaseMode`) the calls are
tree-shaken away regardless of these flags.

## Pluggable observability: `ObserverInspector`

```dart
final recorder = RecordingInspector();
ObserverConfig.inspectors.add(recorder);
// ... later
for (final event in recorder.events) {
  print(event); // ObservableCreateEvent, ObservableUpdateEvent, ...
}
```

Every creation/update/dispose/tracking/warning/effect-run event is exposed
through the `ObserverInspector` interface (`onCreate`/`onUpdate`/
`onDispose`/`onTrack`/`onWarning`/`onEffectRun`), not just printed to the
console. `ConsoleInspector` — the classic colored terminal output — is
itself a formal implementation, called directly and unconditionally so
registering your own inspectors can never duplicate, silence, or reorder
it. `RecordingInspector` ships as an in-memory ring buffer (default 1000
events) for asserting on behavior in tests or building a debug overlay.
An exception thrown by one inspector never blocks the others. Set
`ObserverConfig.captureStackTraces = true` to attach a `StackTrace` to each
event (off by default — capturing one on every event isn't free).

## Standalone reactivity with `effect()`

```dart
final dispose = effect(() {
  print('count is now ${count.value}');
});
// ...
dispose(); // stop reacting
```

Runs immediately, then re-runs whenever any observable read during its
previous run changes — the same auto-tracking `Observer` uses, without a
widget or `BuildContext`. Useful outside the widget tree (a controller
class, a background listener). Workers (`ever`/`once`/`debounce`/`interval`)
remain the right tool for the common single-observable case; `effect` is
for callbacks that read more than one observable, or whose dependencies
change conditionally between runs.

## Escape hatches: `untracked()`, `.peek()`, `.previousValue`

```dart
final result = untracked(() => a.value + b.value); // read without tracking
final current = counter.peek();       // shorthand for the same, single value
final before = counter.previousValue; // value right before the last change
```

`untracked()` reads observables inside its callback without registering
them as dependencies of whatever `Observer`/`Computed`/`effect()` is
currently tracking — useful for a one-off read that shouldn't cause a
rebuild on its own. `previousValue` is only updated by an actual value
change (not by `refresh()`, since the value itself didn't change).

## `ObserverStateMixin`: lifecycle-tied side effects

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
`Observer`. Every registered disposer runs at most once, in registration
order.

## Optional persistence with `ObservableStore`

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

## Bounded undo/redo with `ObservableHistory`

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
exceeded. Independent of the `Observable` it wraps — disposing the history
does not close the underlying observable.

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
widget.

## `package:all_observer/core.dart` — the pure-Dart engine

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
`Computed` (from `all_observer.dart`) are thin `ValueListenable` +
console-logging wrappers over `CoreObservable`/`CoreComputed` — same
engine, same behavior, Flutter added on top.

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

Two independent cycle guards exist for two different shapes of runaway
update: `kMaxNotificationDepth` bounds recursive call-stack depth for
cycles outside any batch (A's listener writes B, B's listener writes A);
`kMaxFlushWaves` bounds iterative wave count for the same shape of cycle
happening inside a batch. Both abort with a descriptive `ObserverCycleError`
instead of a raw stack overflow or an infinite loop.

## Known limitations

- **`Observable.batch()` is a performance optimization, not a consistency
  requirement.** See the diamond-dependency section above — every write is
  already glitch-free without it.
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

## Testing

`all_observer` has no special test harness requirement — `Observable`s and
`Computed`s are plain Dart objects you can read/write/assert on directly in
`flutter_test`/`test`, with no `pumpWidget` needed unless you're testing an
actual `Observer`/widget.

- Turn on `ObserverConfig.strictMode = true` in a test's `setUp` (and call
  `ObserverConfig.reset()` in `tearDown`) to catch an accidentally-empty
  `Observer` or a write-during-build as a thrown error rather than a
  console warning you might miss.
- Test a `Computed` by reading `.value` directly and asserting on it after
  changing its dependencies — no widget required.
- Test workers (`ever`/`once`/`debounce`/`interval`) with `fakeAsync` or
  `flutter_test`'s `FakeAsync`/`tester.pump(duration)` to control timers
  deterministically instead of real `Duration`s.
- Use `RecordingInspector` (registered via `ObserverConfig.inspectors`) to
  assert on the exact sequence of create/update/dispose events a piece of
  code produced, when a plain value assertion isn't precise enough.
- The package's own suite (225 tests as of v1.3.0) lives under `/test`,
  organized by area (`observable/`, `widgets/`, `workers/`, `async/`,
  `core/`) — a useful reference for testing patterns against this API.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Workers](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/workers.md) · Next: [Testing](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md)
