# all_observer

🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) | 🇺🇸 English

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![pub points](https://img.shields.io/pub/points/all_observer?label=pub%20points)](https://pub.dev/packages/all_observer/score)
![354 tests](https://img.shields.io/badge/tests-225-brightgreen)

Reactive state for Flutter with zero dependencies — `final count = 0.obs;` +
`Observer(...)` and you're done.

![all_observer hero](https://raw.githubusercontent.com/CriandoGames/all_observer/main/documentation/images/hero.png)

## Table of contents

- [Features](#features)
- [Installing](#installing)
- [Typed observable aliases](#typed-observable-aliases)
- [Custom logging / ObserverInspector](#custom-logging--observerinspector)
- [Counter app step by step](#counter-app-step-by-step)
- [The building blocks](#the-building-blocks)
- [Observer vs watch(context) — choosing the right one](#observer-vs-watchcontext--choosing-the-right-one)
- [Comparison](#comparison)
- [When to use it (and when not to)](#when-to-use-it-and-when-not-to)
- [Documentation](#documentation)
- [Other packages by us](#other-packages-by-us)

## Features

- 🪶 **Zero dependencies** — the whole reactive core is built on `Dart`/`Flutter` alone, nothing else to keep in sync with your Flutter version.
- ✂️ **No boilerplate, no code generation** — `final count = 0.obs;` plus `Observer(() => ...)` is a complete, working reactive pair.
- 🎯 **Granular rebuilds** — dependencies are discovered by *reading* `.value` during a build, so only the widget that actually reads a value rebuilds.
- 🛡️ **Safe by default** — glitch-free diamond dependencies, race-safe async, unmounted-widget guards, and friendly warnings instead of crashes (with opt-in `strictMode` for CI).
- 🧪 **Testable by design** — `Observable`/`Computed` are plain Dart objects, no wrapper/DI required to test them; see [Testing](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md).
- 🔌 **`ValueListenable` interop** — `Observable<T>` *is* a `ValueListenable<T>`, so it drops straight into `ValueListenableBuilder`, `AnimatedBuilder`, `Listenable.merge`.
- 🩺 **Built-in colored debug logging** — flip `ObserverConfig.logging = true` and watch every create/update/track/dispose event in your terminal.

## Installing

```
flutter pub add all_observer
```

```yaml
dependencies:
  all_observer: ^1.5.4
```

```dart
import 'package:all_observer/all_observer.dart';
```

## Typed observable aliases

`ObsBool`, `ObsInt`, `ObsDouble`, and `ObsString` are lightweight `typedef`
aliases for common `Observable<T>` types. They are only syntactic sugar: they
add no classes or behavior.

```dart
final loading = ObsBool(false, name: 'loading');
final count = ObsInt(0, name: 'count');

Observer(() => Text('${count.value}'));
count.value++;
```

## Custom logging / ObserverInspector

`ObserverInspector` is the `all_observer` conceptual equivalent of bloc's
`BlocObserver`: a global, pluggable observability API for forwarding typed
lifecycle, update, dependency-tracking, warning, effect, and scope events to
your own logger, analytics service, or test audit trail.

Unlike bloc's single observer slot, `ObserverConfig.inspectors` is already a
list, so multiple inspectors can be registered directly. An exception from
one inspector is isolated: other inspectors and the reactive update continue
normally. Set `ObserverConfig.captureStackTraces = true` only while debugging
when event stack traces are needed.

The built-in `ConsoleInspector` remains controlled by
`ObserverConfig.logging`, `warnings`, and `logLevel`; custom inspectors are
additional sinks and do not duplicate, replace, or silence that console
output. `RecordingInspector` provides a bounded in-memory audit trail for
tests.

```dart
class AppObserverInspector extends ObserverInspector {
  @override
  void onCreate(ObservableCreateEvent event) {
    logger.info('created ${event.label}');
  }

  @override
  void onUpdate(ObservableUpdateEvent event) {
    logger.info('${event.label}: ${event.oldValue} -> ${event.newValue}');
  }

  @override
  void onWarning(WarningEvent event) {
    logger.warning('${event.label}: ${event.suggestion ?? ''}');
  }

  @override
  void onDispose(ObservableDisposeEvent event) {
    logger.info('disposed ${event.label}');
  }
}

void main() {
  ObserverConfig.inspectors.add(AppObserverInspector());
  runApp(const App());
}
```

## Counter app step by step

### Step 1 — Create an observable

```dart
final count = 0.obs; // ObservableInt
```

`.obs` wraps any value in an `Observable` — `count` now holds `0` and can be watched for changes.

### Step 2 — Wrap your UI in an Observer

```dart
import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

final count = 0.obs;

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Counter')),
      body: Center(
        child: Observer(() => Text('${count.value}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Run it inside any `MaterialApp(home: CounterPage())`.

### Step 3 — Update the value

```dart
onPressed: () => count.value++,
```

Only the `Observer(() => Text('${count.value}'))` above rebuilds — nothing else in `CounterPage` re-renders, because it's the only widget that read `count.value` during its build.

### Step 4 — Watch it happen

```dart
ObserverConfig.logging = true;
```

```
[all_observer] ✚ Observable<int>(count) created → 0
[all_observer] 👁 Observer(unnamed) tracking: [count]
[all_observer] ↻ Observable<int>(count): 0 → 1
```

<!-- TODO: add result GIF — record the counter demo above with ObserverConfig.logging = true, showing taps on the FAB alongside the colored terminal log lines updating in sync. -->

## The building blocks

### `Observable`

Any value wrapped with `.obs` (or `Observable<T>(initial)` for custom types). Reading `.value` inside a tracked builder registers a dependency; writing only notifies when the new value differs.

```dart
final name = Observable<User?>(null, name: 'user');
name.value = User('Carlos');
```

[More about `Observable` here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md).

### `Observer`

Auto-tracking widget: dependencies are re-discovered on every build, so conditional reads work out of the box.

```dart
Observer(() => Text('${count.value}'));
```

[More about `Observer` here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md).

### `watch(context)` — no wrapper needed

Any widget can subscribe its own element directly from `build()`; only
that widget rebuilds when the value changes.

```dart
@override
Widget build(BuildContext context) => Text('${count.watch(context)}');
```

[More about `watch(context)` (including its lazy-cleanup trade-off) here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md).

### `Computed`

Lazy, memoized derived value, built on the same tracker `Observer` uses.

```dart
final fullName = Computed(() => '${firstName.value} ${lastName.value}');
Observer(() => Text(fullName.value)); // recomputes only when needed
```

[More about `Computed` here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md).

### Reactive collections

`ObservableList`/`ObservableMap`/`ObservableSet` behave like their built-in counterparts, notifying at most once per mutating call.

```dart
final items = <String>[].obs;
Observer(() => Text('${items.length} items'));
items.addAll(['one', 'two']); // notifies once, not twice

items.insertAll(1, ['one and a half', 'one and three quarters']); // notifies once
final startsWithOne = items.where((e) => e.startsWith('one')); // read, no mutation
```

[More about collections here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md).

### `ObservableFuture` (async state)

Runs a `Future` and tracks its loading/data/error lifecycle, with race-safe refreshes.

```dart
final userFuture = ObservableFuture<User>(() => api.fetchUser(id));
Observer(() => userFuture.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (user) => Text(user.name),
  error: (error, stackTrace) => Text('Error: $error'),
));
```

[More about async state here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/async.md).

### Workers

`ever`, `once`, `debounce`, `interval` — side effects driven by an observable change, without hand-rolled `addListener` calls.

```dart
final query = ''.obs;
final search = debounce(query, (String value) => runSearch(value),
    time: const Duration(milliseconds: 400));
```

[More about workers here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/workers.md).

### `batch`

Coalesces multiple writes so manual (`listen`/`ever`) subscribers notify once instead of once per write — `Observer` already coalesces rebuilds per frame on its own.

[More about `batch` and diamond dependencies here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md).

## Observer vs watch(context) — choosing the right one

Both use the **exact same dependency tracker** and re-discover dependencies on every build — neither is "smarter" than the other. The difference is where the subscription lives and how much code you write.

### Quick-decision table

| Situation | Reach for |
|---|---|
| Small leaf widget whose entire `build()` is reactive | `watch(context)` |
| One reactive slice inside a large `build()` (e.g. only a `Text` in a `Scaffold`) | `Observer(() => ...)` |
| Expensive static subtree that should never rebuild | `Observer.withChild(builder:, child:)` |
| Long-lived global observable read by many short-lived screens | `Observer` (eager `dispose()`) |
| Reactive value inside an `Observer` builder | `watch(context)` — delegates to the enclosing context, **no double subscription** |

### Side-by-side

```dart
// watch(context) — the widget subscribes itself, no wrapper
class CounterText extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Text('${count.watch(context)}');
}

// Observer — a wrapper widget owns the subscription
Observer(() => Text('${count.value}'));
```

Both rebuild **only the widget that read the value**. The practical difference shows up when the `build()` is large:

```dart
// watch rebuilds the whole Scaffold when count changes
Widget build(BuildContext context) {
  final n = count.watch(context); // <-- subscribes this Element
  return Scaffold(
    body: Center(child: Text('$n')),
    // ... 50 other widgets
  );
}

// Observer rebuilds only the Text node
Widget build(BuildContext context) {
  return Scaffold(
    body: Center(
      child: Observer(() => Text('${count.value}')), // <-- only this rebuilds
    ),
    // ... 50 other widgets
  );
}
```

### Cleanup behaviour

| | Cleanup timing |
|---|---|
| `Observer` | Immediate — `dispose()` unsubscribes on unmount |
| `watch(context)` | Lazy — the dead subscription is released on the **first notification after unmount** (guaranteed no-op: nothing rebuilds, nothing throws). On an observable that never changes again the inert listener persists — prefer `Observer` for long-lived globals. |

### The rule of thumb

> **Leaf widget, whole `build()` is reactive → `watch(context)`.**  
> **Reactive slice inside a big `build()`, static subtree, or eager cleanup → `Observer`.**

They are additive and compose freely. A `watch` call inside an `Observer` builder simply reads the value and delegates to the enclosing tracker — no extra subscription is created.

## Comparison

| | all_observer | GetX | Riverpod | Bloc | MobX | signals |
|---|---|---|---|---|---|---|
| External dependencies | Zero | Zero (all-in-one) | `riverpod` (+ generator, common) | `bloc`, `flutter_bloc` | `mobx`, `build_runner` | Zero |
| Code generation | None | None | Optional, common in practice | None | Required (`@observable`/`@action`) | None |
| Boilerplate | Minimal (`.obs` + `Observer`) | Minimal | Provider declarations | Events/states/handlers | Annotated store classes | Minimal |
| Rebuild granularity | Per-read, auto-tracked | Per-read, auto-tracked | Per `ref.watch` | Per `BlocBuilder`/selector | Per-read, auto-tracked | Per-read, auto-tracked |
| Learning curve | Low | Low–medium | Medium | Medium–high | Medium | Low |
| Scope | Reactivity only | Full framework (state+routing+DI) | State + DI graph | State machine/event architecture | Reactivity + actions | Reactivity only |

`all_observer` intentionally doesn't do routing, DI, or snackbars — that's a
design choice, not a gap. [Full, detailed comparison here](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/comparison.md).

## When to use it (and when not to)

Reach for `all_observer` when you want reactive state — counters, form fields,
loading flags, a reactive list, a computed summary — without adopting a full
architecture, and you want it composable with whatever DI/routing you already
use.

Reach for something else when you specifically need what it specializes in:
a compile-time-checked DI graph (Riverpod), an all-in-one framework with
routing and DI (GetX), or an auditable event/state architecture for a large
team (Bloc). `all_observer` has no opinion on where state *lives*, only on
how it *notifies*, so it composes with any of them.

## Documentation

- [Core concepts](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md) — `Observable`, `Observer`, tracking, `Computed`.
- [Collections](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md) — `ObservableList`/`Map`/`Set`.
- [Async](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/async.md) — `ObservableFuture`, `ObservableStream`, `AsyncState`.
- [Workers](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/workers.md) — `ever`, `once`, `debounce`, `interval`.
- [Advanced](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md) — `batch`, diamond dependencies, `equals`, `setValue`, `strictMode`, logging, design decisions, limitations.
- [Testing](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md) — how to test widgets and controllers that use all_observer, with real examples from the example app.
- [Comparison](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/comparison.md) — detailed comparison vs GetX, Riverpod, Bloc, MobX, signals.
- [Migrating from GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/migration_from_getx.md).
- [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/faq.md) — troubleshooting and common questions.
- [Tutorials](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/tutorials.md) — four small examples: a toggle button, a loading screen, a login screen, an infinite list.

## Other packages by us

`all_observer` is part of a small family of zero/low-dependency Dart & Flutter
packages published under the
[`opensource.tatamemaster.com.br`](https://pub.dev/publishers/opensource.tatamemaster.com.br/packages)
verified publisher:

| Package | Version | Description |
|---|---|---|
| [`all_validations_br`](https://pub.dev/packages/all_validations_br) | [![pub](https://img.shields.io/pub/v/all_validations_br.svg)](https://pub.dev/packages/all_validations_br) | Brazilian document validation (CPF, CNPJ, CNH, PIX), input formatters/masks, JWT/UUID/currency/encryption utilities. |
| [`all_box`](https://pub.dev/packages/all_box) | [![pub](https://img.shields.io/pub/v/all_box.svg)](https://pub.dev/packages/all_box) | Synchronous key-value storage with crash-safe writes and a pure-Flutter reactive layer. |
| [`all_image_compress`](https://pub.dev/packages/all_image_compress) | [![pub](https://img.shields.io/pub/v/all_image_compress.svg)](https://pub.dev/packages/all_image_compress) | Pure-Dart image compression (JPEG, PNG, GIF, BMP, TIFF, WebP), running in isolates. |

## 👥 Contributors

[![Contributors](https://contrib.rocks/image?repo=CriandoGames/all_observer)](https://github.com/CriandoGames/all_observer/graphs/contributors)

Made with [contrib.rocks](https://contrib.rocks).

## How to contribute

Contributions are welcome! Read [CONTRIBUTING.md](CONTRIBUTING.md) to get started.

---

Issues and pull requests are welcome at the
[GitHub repository](https://github.com/CriandoGames/all_observer). Licensed under [MIT](LICENSE).
