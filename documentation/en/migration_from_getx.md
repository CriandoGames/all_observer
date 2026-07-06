🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/migration_from_getx.md) | 🇺🇸 English

# Migrating from GetX

`all_observer` covers the same reactive-state concepts GetX does, under
mostly matching names — this is a concept-by-concept map, not a promise
that every GetX API has a drop-in replacement.

## Concept map

| GetX | `all_observer` | Notes |
|---|---|---|
| `.obs` | `.obs` | Same syntax: `final count = 0.obs;` |
| `Rx<T>` / `RxInt`/`RxString`/... | `Observable<T>` / `ObservableInt`/`ObservableString`/... | Same specialization pattern |
| `Obx(() => ...)` | `Observer(() => ...)` | Both auto-track `.value` reads |
| `GetX<Controller>`/`GetBuilder` | `Observer` (state lives in a plain class you own) | No controller-registration step needed |
| `ever`, `once`, `debounce`, `interval` | Same names: `ever`, `once`, `debounce`, `interval` | Signatures differ slightly — see [workers.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/workers.md) |
| `.value` read/write | `.value` read/write | Direct equivalent |
| Reactive list/map (`RxList`, `RxMap`) | `ObservableList`, `ObservableMap`, `ObservableSet` | See [collections.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md) |
| `GetxController.onClose` | `ScopedObserverMixin.disposeScope()` | Workers/`Computed`/`effect`s created via the mixin's scope die in one call — see below |
| `Get.put`/`Get.find` (DI) | *No equivalent* | Bring your own DI — see below |
| `Get.to`/`Get.off` (routing) | *No equivalent* | Use Flutter's `Navigator`/`Router` |
| `Get.snackbar`/dialogs | *No equivalent* | Use `ScaffoldMessenger`/`showDialog` directly |

## Incremental migration

Both libraries can coexist during a transition — `all_observer` doesn't
register anything globally, so introducing it alongside existing GetX code
is safe. A common path:

1. New features use `Observable`/`Observer` directly.
2. Existing `GetxController` classes keep their GetX state for now; convert
   fields to `Observable`s one controller at a time as they're touched.
3. Keep GetX's DI (`Get.put`/`Get.find`) and routing until you've decided
   what replaces them — `all_observer` has no opinion on either, so this
   isn't blocking.

```dart
// Before (GetX)
class CounterController extends GetxController {
  final count = 0.obs;
  void increment() => count.value++;
}

// After (all_observer) — same shape, no controller base class required
class CounterController {
  final count = 0.obs;
  void increment() => count.value++;
  void dispose() => count.close();
}
```

## Replacing `onClose` with `ScopedObserverMixin`

In GetX, workers created inside a `GetxController` are typically canceled
in `onClose`, called by GetX's DI when the controller is removed. The
equivalent here (since 1.4.0) is `ScopedObserverMixin`: everything created
inside `scoped(...)` — workers, `Computed`s, `effect()`s — is registered
in an internal `ReactiveScope`, and `disposeScope()` is your `onClose`:

```dart
// Before (GetX)
class SearchController extends GetxController {
  final query = ''.obs;
  late Worker _debouncer;

  @override
  void onInit() {
    super.onInit();
    _debouncer = debounce(query, runSearch,
        time: const Duration(milliseconds: 400));
  }

  @override
  void onClose() {
    _debouncer.dispose();
    super.onClose();
  }
}

// After (all_observer) — no worker fields to track by hand
class SearchController with ScopedObserverMixin {
  final query = ''.obs;

  SearchController() {
    scoped(() {
      debounce(query, runSearch, time: const Duration(milliseconds: 400));
    });
  }

  void close() => disposeScope(); // wire to whatever owns this controller
}
```

One honest difference: GetX's DI *calls* `onClose` for you when the
controller leaves memory; `all_observer` has no DI, so whatever owns the
controller (a `State`'s `dispose`, your DI container's teardown) must call
`close()`/`disposeScope()`. The bookkeeping inside the controller is what
the scope eliminates. See the "Scoped cleanup with `ReactiveScope`"
section in [advanced.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md)
for the full contract.

## What doesn't migrate

`all_observer` only handles *reactivity*, by design — these need a
different tool, not a port:

- **Dependency injection / service location.** Bring your own DI (a simple
  constructor-passed singleton, an `InheritedWidget`, or a dedicated DI
  package) and store `Observable`s inside the services/controllers it
  manages.
- **Routing / navigation.** Use Flutter's own `Navigator`/`Router`, or a
  dedicated routing package.
- **Snackbars / dialogs / overlays.** Use Flutter's own
  `ScaffoldMessenger`, `showDialog`, `showModalBottomSheet`, etc. directly
  — `all_observer` has no UI-side-effect layer to hook into these.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Comparison](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/comparison.md) · Next: [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/faq.md)
