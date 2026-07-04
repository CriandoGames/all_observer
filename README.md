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

- `ObservableList`, `ObservableMap`, `ObservableSet`: reactive collections; reading any member tracks it, mutating any member notifies.
- `ObserverValue<T>`: local, self-contained reactive state without managing an observable's lifecycle separately.
- `ever`, `once`, `debounce`, `interval`: workers for side effects driven by observable changes.
- See `/example` for a runnable demo (counter, reactive list, worker, debug-log toggle).

## Contributing

Issues and pull requests are welcome at the
[GitHub repository](https://github.com/CriandoGames/all_observer).
