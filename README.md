# all_observer

🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) | 🇺🇸 English

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![pub points](https://img.shields.io/pub/points/all_observer?label=pub%20points)](https://pub.dev/packages/all_observer/score)
![225 tests](https://img.shields.io/badge/tests-225-brightgreen)

Reactive state for Flutter with zero dependencies — `final count = 0.obs;` +
`Observer(...)` and you're done.

![all_observer hero](https://raw.githubusercontent.com/CriandoGames/all_observer/main/documentation/images/hero.png)

## Table of contents

- [Features](#features)
- [Installing](#installing)
- [Counter app step by step](#counter-app-step-by-step)
- [The building blocks](#the-building-blocks)
- [Comparison](#comparison)
- [When to use it (and when not to)](#when-to-use-it-and-when-not-to)
- [Documentation](#documentation)
- [Other packages by us](#other-packages-by-us)

## Features

- 🪶 **Zero dependencies** — the whole reactive core is built on `Dart`/`Flutter` alone, nothing else to keep in sync with your Flutter version.
- ✂️ **No boilerplate, no code generation** — `final count = 0.obs;` plus `Observer(() => ...)` is a complete, working reactive pair.
- 🎯 **Granular rebuilds** — dependencies are discovered by *reading* `.value` during a build, so only the widget that actually reads a value rebuilds.
- 🛡️ **Safe by default** — glitch-free diamond dependencies, race-safe async, unmounted-widget guards, and friendly warnings instead of crashes (with opt-in `strictMode` for CI).
- 🔌 **`ValueListenable` interop** — `Observable<T>` *is* a `ValueListenable<T>`, so it drops straight into `ValueListenableBuilder`, `AnimatedBuilder`, `Listenable.merge`.
- 🩺 **Built-in colored debug logging** — flip `ObserverConfig.logging = true` and watch every create/update/track/dispose event in your terminal.

## Installing

```
flutter pub add all_observer
```

```yaml
dependencies:
  all_observer: ^1.3.0
```

```dart
import 'package:all_observer/all_observer.dart';
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
- [Advanced](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md) — `batch`, diamond dependencies, `equals`, `setValue`, `strictMode`, logging, design decisions, limitations, testing.
- [Comparison](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/comparison.md) — detailed comparison vs GetX, Riverpod, Bloc, MobX, signals.
- [Migrating from GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/migration_from_getx.md).
- [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/faq.md) — troubleshooting and common questions.

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
