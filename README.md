# all_observer

🇧🇷 [Leia em Português](README.pt-BR.md)

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/CriandoGames/all_observer/ci.yml?branch=main)](https://github.com/CriandoGames/all_observer/actions)

Reactive state for Flutter, zero dependencies. `Observable` values plus an
auto-tracking `Observer` widget — a small, safe, dependency-free core for
apps that want reactivity without a full state-management framework.

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

`Observable.select`-style derivation (e.g. `user.select((u) => u.name)`)
is intentionally not a separate API: write it directly as
`Computed(() => user.value.name)`.

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
- `Computed<T>`: lazy, memoized derived values built on the same dependency tracker as `Observer`.
- `Observable.batch`: coalesces multiple writes into one notification per changed observable, for manual subscribers.
- `ObserverValue<T>`: local, self-contained reactive state without managing an observable's lifecycle separately.
- `ever`, `once`, `debounce`, `interval`: workers for side effects driven by observable changes.
- A synchronous update cycle (A's listener writes B, B's listener writes A, ...) is stopped after a bounded notification depth with a descriptive error, instead of a raw stack overflow; an exception thrown inside one listener never stops the other listeners of the same observable from running.
- See `/example` for a runnable demo (counter, reactive list, worker, debug-log toggle), and `/benchmark` for manual Stopwatch-based microbenchmarks.

## Contributing

Issues and pull requests are welcome at the
[GitHub repository](https://github.com/CriandoGames/all_observer).
