# The reactive engine (`package:all_observer/engine.dart`)

`all_observer` ships its lowest layer as a **public, standalone, pure-Dart
engine** that anyone can build a reactive library on top of. The package's
own `Observable`/`Computed` run on it — you get the exact same machinery.

```
┌─────────────────────────────────────────────┐
│  all_observer.dart   (Flutter: Observer,    │
│  watch(), collections, async, workers)      │
├─────────────────────────────────────────────┤
│  core.dart           (CoreObservable,       │
│  CoreComputed, BatchScope, inspectors)      │
├─────────────────────────────────────────────┤
│  engine.dart         (ReactiveEngine —      │
│  the graph. Zero policy. Yours to extend.)  │
└─────────────────────────────────────────────┘
```

## What the engine is (and deliberately is not)

The engine owns **only graph mechanics**:

- a dependency graph of `ReactiveNode`s connected by `ReactiveLink`s
  (intrusive doubly-linked lists: O(1) insert/remove, no hashing, no
  allocation churn when the same dependencies are re-tracked);
- node state as bit flags in a single `int` (`ReactiveFlags`);
- **push** phase: `propagate` walks subscribers iteratively (explicit
  stack — graph depth is bounded by heap, not call stack) marking them
  "maybe stale" (`pending`) and notifying watchers;
- **pull** phase: `checkDirty` confirms staleness lazily, updating stale
  dependencies deepest-first, only when a value is actually needed.

It has **no policy**. What "update a node" means, how effects are
scheduled, what happens when a node loses its last subscriber — all of
that is delegated to you through three abstract hooks:

| Hook | Called when | You typically |
|---|---|---|
| `bool update(node)` | a stale node must refresh | recompute the value; return `true` only if it changed (your `equals` lives here — returning `false` cuts propagation below this node) |
| `void notify(node)` | a node flagged `watching` is reached during `propagate` | queue the node to run after the current write/batch |
| `void unwatched(node)` | a node loses its last subscriber | release resources, drop dependencies, stop work |

## Tutorial: build your own signals in ~100 lines

A complete, runnable version of everything below lives in
`test/engine/fixtures/mini_preset.dart` (exercised by
`test/engine/reactive_engine_test.dart`). The essential steps:

### 1. The engine subclass and global tracking state

```dart
import 'package:all_observer/engine.dart';

int cycle = 0;                 // tracking-cycle counter for link()
ReactiveNode? activeSub;       // who is currently (re)computing
MyEffect? queuedHead, queuedTail;

class MyEngine extends ReactiveEngine {
  @override
  bool update(ReactiveNode node) => switch (node) {
        MyComputed<Object?>() => node.recompute(),
        MySignal<Object?>() => node.commit(),
        _ => false,
      };

  @override
  void notify(ReactiveNode node) {
    final MyEffect e = node as MyEffect;
    e.flags = e.flags & ~ReactiveFlags.watching; // avoid double-queue
    // append e to the queuedHead/queuedTail linked list...
  }

  @override
  void unwatched(ReactiveNode node) {
    // e.g. a computed nobody watches: drop its deps, mark it dirty.
  }
}

final MyEngine engine = MyEngine();
```

### 2. A signal: write = mark + propagate; read = link

```dart
class MySignal<T> extends ReactiveNode {
  MySignal(this._current)
      : _pending = _current,
        super(flags: ReactiveFlags.mutable);
  T _current, _pending;

  void set(T v) {
    if (identical(_pending, v)) return;
    _pending = v;
    flags = ReactiveFlags.mutableDirty;      // "definitely changed"
    final subs = this.subs;
    if (subs != null) {
      engine.propagate(subs);                // push: cheap flag marks
      flushEffects();                        // or defer if batching
    }
  }

  T get() {
    if (flags.hasAny(ReactiveFlags.dirty)) commit();
    final sub = activeSub;
    if (sub != null) engine.link(this, sub, cycle);  // auto-track
    return _current;
  }

  bool commit() {
    flags = ReactiveFlags.mutable;
    if (identical(_current, _pending)) return false;
    _current = _pending;
    return true;
  }
}
```

### 3. A computed: lazy pull with re-tracking

The re-tracking discipline is the heart of the engine. On every rerun:

1. `depsTail = null` — resets the *re-tracking cursor*;
2. set `flags = ReactiveFlags.mutableChecking`, swap `activeSub` to the
   node, bump `++cycle`;
3. run the user computation — every `get()` it touches calls
   `engine.link(dep, this, cycle)`, which **reuses existing links in
   place** (a rerun that reads the same things allocates nothing);
4. in a `finally`: restore `activeSub`, clear `recursedCheck`, and unlink
   everything left *after* the cursor — dependencies not re-read this
   time (that's how conditional branches stop being dependencies).

```dart
T get() {
  final f = flags;
  if (f.hasAny(ReactiveFlags.dirty) ||
      (f.hasAny(ReactiveFlags.pending) && _confirm())) {
    if (recompute()) {                        // value actually changed
      final subs = this.subs;
      if (subs != null) engine.shallowPropagate(subs); // pending -> dirty
    }
  } else if (f == ReactiveFlags.none) {
    // first evaluation: same tracking dance, no notification
  }
  final sub = activeSub;
  if (sub != null) engine.link(this, sub, cycle);
  return _value as T;
}

bool _confirm() {
  if (engine.checkDirty(deps!, this)) return true;  // pull confirms
  flags = flags & ~ReactiveFlags.pending;           // false alarm
  return false;
}
```

`pending` vs `dirty` is what makes writes cheap: `propagate` only says
"*maybe* stale"; `checkDirty` walks upstream and, if some `equals` cut the
change on the way, your computed never re-runs at all.

### 4. An effect: a `watching` node the engine notifies

Create the node with `flags: ReactiveFlags.watching`, run it once with the
same tracking discipline as a computed, and when `notify` fires, queue it;
on flush, re-run it (or first `checkDirty` to skip false alarms). Stopping
an effect = set `flags = none` and unlink its deps in reverse — the engine
calls `unwatched` up the chain automatically.

### 5. Batching

Keep a `batchDepth` counter: writes still `propagate` (marking is cheap
and idempotent) but only flush the effect queue when the outermost batch
ends. Deduplication is free — a node already marked is not re-queued.

## Rules of the road

- **Single isolate.** The engine has no locks; use it from one isolate.
- **Always pair the tracking dance with `try`/`finally`** (restore
  `activeSub`, clear `recursedCheck`, purge stale links) — even when the
  user computation throws.
- **`update()` must be honest.** Returning `true` when nothing changed
  causes over-notification; returning `false` on change starves
  downstream nodes.
- **Don't touch `flags` outside the documented transitions** — the
  propagation algorithms rely on them precisely.
- The named masks (`ReactiveFlags.mutableDirty`, `stale`,
  `watchingOrChecking`, …) exist so your code never contains a bare `17`.

## How all_observer itself binds the engine

The package preset lives in `lib/src/core/engine_bridge.dart` (exported by
`core.dart`) and integrates through exactly two seams:

- `DependencyTracker.reportRead` — while a `CoreComputed` recomputes,
  every read links that registry's engine node as a dependency;
- `ListenerRegistry.notifyAll` — when the two-phase `BatchScope` flush
  delivers a change, the registry's node propagates through the engine,
  and each live computed's internal `WatcherNode` schedules a pull in
  phase 2 of the same flush.

That's why `Observable`, collections, async and widgets needed no changes
— and why everything you already know from `core_concepts.md` still holds.

`effect()` remains a higher-level scheduler on top of the same tracking
stack. It records writes made while its callback is tracked and suppresses
only the self-invalidation from the current batch flush; later external
writes still propagate through the engine bridge and re-run the effect. This
keeps push-pull graph mutation behavior compatible with the package-level
batch guarantees.
