# Architecture

This document explains how `all_observer`'s reactive graph works internally,
and records the design decisions behind it as short ADRs. It exists to
reduce bus factor: someone who has never touched this codebase should be
able to read this file and understand *why* the code is shaped the way it
is, not just *what* it does.

## How the graph works

Three pieces cooperate:

- **`DependencyTracker`** (`lib/src/core/dependency_tracker.dart`): a
  reentrant stack of `TrackingContext`s. Whenever any observable's `value`
  getter runs, it calls `DependencyTracker.reportRead`, which — if a
  context is currently on top of the stack — subscribes that context's
  `onDependencyChanged` callback to the observable's registry. This is how
  `Observer`, `Computed`, and `Effect` (Phase 1) all discover their
  dependencies: by simply reading `.value` inside a tracked callback, with
  no separate declaration step. Conditional/dynamic dependencies work
  because tracking re-runs from scratch on every recompute — whatever is
  read *this* time is what gets subscribed, and the old subscription list
  is disposed first (`Computed._clearDependencies`), so a branch that stops
  being read stops being depended upon.

- **`ListenerRegistry`** (`lib/src/core/listener_registry.dart`): the
  per-observable set of listeners. `notifyAll` snapshots the listener set
  before iterating (so listeners that subscribe/unsubscribe mid-notification
  don't affect the current pass) and wraps each listener in its own
  `try`/`catch` (one failing listener never blocks the rest). A global
  `_notificationDepth` counter bounds *recursive* notification depth
  (`kMaxNotificationDepth`, a listener-of-A-writes-B-whose-listener-writes-A
  cycle across separate call stacks).

- **`BatchScope`** (`lib/src/core/batch_scope.dart`): the piece that makes
  the graph glitch-free. `notifyOrQueue` (called by every write) never
  notifies synchronously. If an explicit `Observable.batch()` is active, it
  queues the registry. If not, it opens a *micro-batch* right there — a
  `BatchScope.run` scoped to just that one write — so even a single
  standalone `a.value = x` goes through the same two-phase flush as an
  explicit batch.

### The two-phase flush (why the diamond problem doesn't occur)

`BatchScope._flushPending` drains two queues as a single fixed-point loop,
with `isActive` (via a separate `_flushing` flag) held `true` for the
entire loop — not just while the outer `batch()` call is on the stack:

1. `_pending` — plain `Observable`/collection registries waiting to notify.
2. `_dirtyFlushCallbacks` — `Computed`s marked dirty, waiting to recompute.

Each wave notifies every currently-pending registry first, *then* flushes
every currently-dirty `Computed`. A `Computed` recomputing during phase 2
may itself change and mark its own dependents dirty — those go into the
*next* wave, not the current one, because `isActive` is still `true` so
`Computed._onDependencyChanged` keeps deferring instead of recomputing
inline. The loop continues until both queues drain, bounded by
`kMaxFlushWaves` as a cycle guard.

This is why the diamond case (`a -> b, a -> c, [b,c] -> d`) does not glitch:
a write to `a` queues `b` and `c` in `_pending` for wave 1. Wave 1 notifies
both, which marks `d` dirty (queued in `_dirtyFlushCallbacks`, not run
inline, since `isActive` is true). Wave 2 flushes `d`'s dirty flag: `d`
recomputes now, reading `b.value` and `c.value`, both of which already
hold their post-write values (memoized from wave 1) — never a mix of one
new and one stale. `d` recomputes and notifies its own listeners exactly
once.

### ADR-0001: Micro-batch every write instead of per-node versioning

**Context.** Some reactive libraries (e.g. Preact Signals) solve the
diamond problem with a "push-pull" versioning scheme: each node has a
`_version`, each dependency edge remembers the version it last saw, and a
`Computed` checks versions lazily on read instead of eagerly propagating.

**Decision.** `all_observer` instead makes *every write* — even a bare
`observable.value = x` outside any explicit `batch()` — open an implicit
micro-batch, and lets the existing two-phase fixed-point flush (built for
explicit `Observable.batch()`) do the glitch-free ordering. See T2.1 in
`CHANGELOG.md` (v1.2.0).

**Consequences.** No per-node version counters or extra bookkeeping fields
are needed — `ListenerRegistry` and `Computed`'s existing `_dirty` flag are
enough. The cost is one extra `BatchScope.run` per zero-listener-free write
(mitigated by the fast-path in `notifyOrQueue` that skips the micro-batch
entirely when a registry has no listeners at all). Phase 0 of the v2
roadmap (see `test/observable/computed_graph_test.dart`) exists specifically
to hold this design to its glitch-free promise: diamond, chained, cut
-propagation, and dynamic-dependency scenarios are all asserted there. As
long as that suite passes, the Preact-style versioning algorithm described
in the v2 prompt is **not needed** — this ADR documents that decision
explicitly so a future contributor doesn't reintroduce it without cause.

### ADR-0002: Change-filtering happens at the `Computed` level, not the graph level

**Context.** A `Computed` recomputing after a dependency change doesn't
always produce a different value (e.g. `b = Computed(() => a.value > 10)`
when `a` moves between two values on the same side of the threshold).

**Decision.** `Computed._recompute` always compares the new value against
the cached one with `_equals` (default `==`) before calling
`_registry.notifyOrQueue()`. If unchanged, nothing downstream is touched —
no dirty flag is set on dependents, no wave is queued for them.

**Consequences.** This is what makes propagation cut off correctly: a
`Computed` that recomputes but doesn't change acts as a firewall for
everything downstream of it, at zero extra cost (the comparison is O(1) for
most `T`). The tradeoff is that `T`'s `==` must be meaningful; types where
it isn't (e.g. comparing only a subset of fields) should pass a custom
`equals` callback to the `Computed`/`Observable` constructor.

## Cycle guards

Two independent depth/wave limits exist, guarding two different shapes of
cycle:

- `kMaxNotificationDepth` (`listener_registry.dart`) — recursive call-stack
  depth, for cycles that happen *outside* any batch (a listener writes
  synchronously to another observable whose listener writes back).
- `kMaxFlushWaves` (`batch_scope.dart`) — iterative wave count, for cycles
  that happen *inside* a batch (writes there become queued
  re-notifications instead of recursive calls, so the shape of the cycle
  changes from "stack overflow" to "infinite while loop" — this guard
  catches that instead).

Both abort by throwing an `ObserverCycleError`
(`lib/src/errors/observer_cycle_error.dart`) — reported through
`CoreErrorReporting.report` (see below), which forwards it to
`FlutterError.reportError` — rather than hanging or crashing silently.

## The `core/` vs Flutter split

`lib/src/core/` (`CoreObservable`, `CoreComputed`, `DependencyTracker`,
`ListenerRegistry`, `BatchScope`, `ObserverInspector`, `RecordingInspector`,
`CoreErrorReporting`, `untracked()`) has **zero import of
`package:flutter`**, and is re-exported standalone through
`package:all_observer/core.dart` for use outside Flutter (a CLI tool, a
server, a background isolate). `Observable`/`Computed` (in
`lib/src/observable/`) are thin wrappers: each holds a
`final CoreObservable<T> _core`/`CoreComputed<T> _core` and delegates every
operation to it, adding only `ValueListenable<T>` conformance and the
package's `kDebugMode`-gated console logging on top.

**Why a wrapper instead of one class implementing everything directly:**
`ValueListenable`, `kDebugMode`, and `debugPrint` all come from
`package:flutter/foundation.dart`. Splitting the actual tracking/
notification/batching logic into a Flutter-free engine class means it can
be fuzzed, benchmarked, and reused (e.g. by a future non-Flutter package)
without a Flutter SDK on the machine running it, while the public
`Observable`/`Computed` API and behavior stay 100% unchanged for existing
users — this was a purely internal refactor, not a new feature.

**Avoiding double-dispatch:** since `CoreObservable`/`CoreComputed` already
dispatch `ObserverInspector` events (`onCreate`/`onUpdate`/`onDispose`)
directly, the Flutter-side `Observable`/`Computed` call `ObserverLogger.
created/updated/disposed(..., dispatch: false)` — the `dispatch` parameter
skips *only* the fan-out to `ObserverConfig.inspectors`, never the
console-printing path (see `ConsoleInspector`, next section) — so every
event fires exactly once per registered inspector, and the console output
is byte-identical to before this split existed.

## Observability: `ObserverInspector`/`ConsoleInspector`/`RecordingInspector`

Every lifecycle/update/warning/tracking/effect-run event the package emits
is expressed as a plain data class (`ObservableCreateEvent`,
`ObservableUpdateEvent`, `ObservableDisposeEvent`, `TrackEvent`,
`WarningEvent`, `EffectEvent` — `lib/src/core/observer_inspector.dart`) and
routed through the `ObserverInspector` interface (`onCreate`/`onUpdate`/
`onDispose`/`onTrack`/`onWarning`/`onEffectRun`, every method a no-op
default). Two implementations ship with the package:

- **`ConsoleInspector`** (`lib/src/logging/console_inspector.dart`) — the
  package's classic colored terminal output, reproduced faithfully as a
  formal `ObserverInspector`. `ObserverLogger` holds a single internal
  `const ConsoleInspector()` and calls it **directly**, unconditionally, on
  every `created`/`updated`/`disposed`/`warn` call — deliberately *not*
  through `ObserverConfig.inspectors`, so registering your own inspectors
  there can never duplicate, silence, or reorder the default console
  output.
- **`RecordingInspector`** (`lib/src/core/recording_inspector.dart`) — an
  in-memory ring buffer (`maxEvents`, default 1000) of every event, handy
  for asserting on inspector behavior in tests or building a debug overlay.

Register any number of your own via `ObserverConfig.inspectors.add(...)`;
each runs inside its own `try`/`catch` (`dispatchToInspectors`), so one
throwing inspector never blocks the others or the notification it was
reporting on — same isolation principle as `ListenerRegistry.notifyAll`.

## Async: `ObservableFuture`/`ObservableStream` and generation-counter cancellation

`AsyncState<T>` (aliased as `AsyncValue<T>`) is a plain sealed
loading/data/error union with no `Future`/`Stream` machinery of its own.
`ObservableFuture<T>`/`ObservableStream<T>` (`lib/src/observable/async/`)
each drive it from a `Future`/`Stream`, sharing the same race-safety shape:
every call to `run()`/`refresh()` bumps an internal `int _generation`
counter, and the eventual result (or event/error) checks `generation ==
_generation` before writing — a stale call finishing after a newer one
started is silently discarded instead of overwriting fresher state. For
`ObservableStream`, `run()` additionally cancels the previous
`StreamSubscription` before resubscribing, so a stale subscription stops
receiving events altogether (the generation check is a second, belt-
-and-suspenders layer for events already in flight when `cancel()` is
called). No global scheduler or reference counting is needed — the counter
is the entire mechanism.

## Lifecycle helpers: `ObserverStateMixin`, `ObservableStore`, `ObservableHistory`

Three independent, optional building blocks, none of which change the core
graph:

- **`ObserverStateMixin`** (`lib/src/widgets/observer_state_mixin.dart`) —
  a `mixin ... on State<T>` that collects `Disposer`s via `autoDispose`
  (or the `autorun` shortcut for a standalone `effect()`) and runs them all
  in `dispose()`. Purely a bookkeeping convenience over the same `effect()`/
  `Disposer` primitives from Phase 1 — it introduces no new reactive
  mechanism.
- **`ObservableStore<T>`** (`lib/src/core/observable_store.dart`) — a
  three-method (`read`/`write`/`delete`) interface with zero implementation
  in this package, so `all_observer` stays free of any I/O/serialization
  dependency. `Observable.persistWith(store)`
  (`lib/src/observable/observable_store_extensions.dart`) is the only piece
  that touches `Observable` directly: it restores once on binding, then
  writes on every subsequent change, and returns a plain `Disposer` to stop.
  A bridge package (e.g. `all_box`) implements `ObservableStore` against its
  own storage; `all_observer` never depends on how that storage works.
- **`ObservableHistory<T>`** (`lib/src/observable/observable_history.dart`)
  — bounded undo/redo built on a manual `listen()` subscription plus a
  boolean re-entrancy guard (`_applyingHistoryChange`) so `undo()`/`redo()`
  writing back to the `Observable` doesn't get recorded as a brand-new
  history entry. A plain `List<T>` acts as the timeline; exceeding `limit`
  drops from the front and shifts the current index down by one per
  dropped entry.
