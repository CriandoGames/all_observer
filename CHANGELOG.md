## 1.3.0

Additive release — no breaking changes, no new external dependencies.

- **Core/Flutter split:** the reactive engine (`CoreObservable`,
  `CoreComputed`, `DependencyTracker`, `ListenerRegistry`, `BatchScope`) now
  has zero `package:flutter` import and is exposed standalone via
  `package:all_observer/core.dart`. `Observable`/`Computed` are unchanged
  from the outside — they now wrap this engine internally.
- **Standalone reactivity:** `effect()`, plus escape hatches `untracked()`,
  `Observable.peek()`, and `Observable.previousValue`.
- **Pluggable observability:** the `ObserverInspector` interface
  (`onCreate`/`onUpdate`/`onDispose`/`onTrack`/`onWarning`/`onEffectRun`),
  with the classic colored console output now a formal `ConsoleInspector`
  implementation, plus a `RecordingInspector` and
  `ObserverConfig.inspectors`/`captureStackTraces`.
- **Async:** `ObservableStream<T>`, the `Stream` counterpart of
  `ObservableFuture`, with the same generation-counter race safety.
  `AsyncValue<T>` added as an alias for `AsyncState<T>`.
- **Lifecycle helpers:** `ObserverStateMixin` (auto-disposed `effect()`s and
  subscriptions on a `State`), `ObservableStore`/`Observable.persistWith`
  (optional persistence integration point, e.g. for `all_box`), and
  `ObservableHistory`/`Observable.withHistory` (bounded undo/redo).
- **Docs:** `ARCHITECTURE.md` expanded to cover all of the above,
  `CONTRIBUTING.md` added, CI workflow added, and both READMEs gained a
  comparison section against GetX/Riverpod/MobX/flutter_hooks.

Tests: +57 new tests; total 225.

## 1.2.0

Minor release — no breaking changes, no new external dependencies.

Core:

- **T2.1 — Auto-batch (glitch-free by default):** every write — even a
  standalone `observable.value = x` outside any explicit `Observable.batch()`
  — is now automatically routed through the same two-phase fixed-point flush
  that explicit batches use. Diamond dependency graphs (`Computed` A and B
  both derived from source S, `Computed` C depending on A and B) always
  recompute exactly once, always seeing fully settled upstream values — no
  glitch, no explicit `batch()` required. The implementation wraps each
  standalone write in a micro-batch (`BatchScope.run(() => BatchScope.queue(this))`);
  a fast-path skips the overhead entirely when there are no listeners. The
  `kMaxFlushWaves = 100` guard from v1.1.1 (T1.1) is the safety net for any
  in-batch cycle that could result from cascading writes.
- **`Observable.batch()` repositioned as a performance optimization:**
  wrapping multiple writes in `batch()` coalesces them into a single
  notification round (all writes committed first, then each changed observable
  notifies once), instead of opening a micro-batch per write. Use `batch()`
  whenever you write to more than one observable in the same logical action.
- **"Known limitations" section updated in both READMEs:** removed "Diamond
  glitch outside batch" and "Deeper cross-branch cascades" items; replaced
  with a paragraph explaining that `batch()` is now a performance tool, not
  a consistency requirement.

Tests: +5 new tests (T2.1 auto-batch group: diamond without batch, 3-level
cascade, write-in-ever-callback, explicit-batch coalescing, post-close
no-op); total 168.

## 1.1.1


Patch release — no breaking changes, no new external dependencies.

Bug fixes (audit):

- **T1.1 — Flush wave limit (CRITICAL):** `_flushPending` in `batch_scope.dart`
  now has a bounded iteration limit (`kMaxFlushWaves = 100`). A mutual cycle
  `a.listen((v)=>b.value=v+1)` + `b.listen((v)=>a.value=v+1)` inside a
  `batch()` previously caused an infinite loop because `kMaxNotificationDepth`
  only guards nested call-stack recursion, not iterative `while` waves. The
  new guard detects the wave overflow, clears pending queues, and reports a
  descriptive bilingual `FlutterError` instead of hanging indefinitely.
- **T1.2 — `previousData` survives chained `run()` calls:** calling
  `ObservableFuture.run()` a second time before the first completes previously
  silently erased the stale value (`.valueOrNull` returned `null` when state
  was already `AsyncLoading`). Fixed via `_previousDataFromCurrent()` helper:
  `AsyncData` → preserve its value; `AsyncLoading` → propagate its own
  `previousData`; `AsyncError` → `null` (documented deliberate choice).

Documentation:

- **T1.3 — `Observable.refresh()` polymorphic semantics:** new bilingual
  paragraph documenting that subclasses may extend `refresh()` beyond a simple
  notification (e.g. `ObservableFuture.refresh` re-runs the fetch). No code
  change.

Tests: +7 new tests (4 for T1.1 wave-limit scenarios, 3 for T1.2 chained
`run()` cases); total 163.

## 1.1.0


Additive release — no breaking changes, no new external dependencies.

Async:

- `ObservableFuture<T>`: an `Observable<AsyncState<T>>` that runs a `Future<T> Function()` and tracks its loading/data/error lifecycle. Auto-runs by default (`autoStart: true`) or via `run()`/`refresh()`. Race-safe: a generation counter discards a stale `run()`'s result if a newer `run()` started before it resolved, and discards any result that arrives after `close()`.
- `AsyncState<T>` sealed class: `AsyncLoading<T>` (with `previousData` for stale-while-loading UIs), `AsyncData<T>`, `AsyncError<T>`; `when`/`maybeWhen`, `isLoading`/`hasData`/`hasError`/`valueOrNull`, content-based `==`/`hashCode`.

Computed:

- `equals` named parameter on `Computed`'s constructor, mirroring `Observable`'s, for custom change-detection (e.g. floating-point tolerance) on the recomputed value.
- Diamond-glitch mitigation: inside an active `Observable.batch()`, a `Computed`'s recompute is deferred (to the next `value` read, or to end-of-batch, whichever comes first) instead of running eagerly per upstream notification — so a diamond-shaped dependency graph recomputes at most once per batch, with every dependency already at its final value. Outside `batch`, the previous eager-recompute-per-notification behavior is unchanged and documented as a known limitation.

Widgets:

- `Observer.withChild` named constructor: rebuilds only the part of the subtree the builder itself constructs, reusing a static `child` widget across rebuilds instead of reconstructing it — for expensive widgets that don't depend on any observable.

Observable:

- `Observable.setValue(T newValue)`: equivalent to `value = newValue`, usable as a tear-off (e.g. directly as an `onChanged` callback) and the unambiguous way to assign `null` to an `Observable<T?>` (unlike `call(null)`, which reads instead of assigns).
- `Observable<T>.select<R>(R Function(T value) selector, {String? name})` extension: sugar over `Computed(() => selector(value), name: name)` for a narrower, memoized derived value. Caller owns and must `close()` the returned `Computed`.

Performance:

- `ListenerRegistry` now backed by a `LinkedHashSet<VoidCallback>` instead of a `List`, making `add`/`remove`/`contains` O(1) instead of O(n), while preserving insertion order and native deduplication. See `benchmark/listener_registry_benchmark.dart`.

Other:

- `example/` reworked into a multi-page app (bottom navigation) with five focused demos: counter + `Computed`, debounced search, `ObservableFuture` async states, `Observable.batch` form saving, and `Observer`/`ValueListenableBuilder` interop — each in its own file under `example/lib/demos/`.
- README (EN/PT-BR): new "Migrating from other reactive state solutions" section (concept-based equivalence table) and a "Known limitations" section (diamond glitch outside `batch`, `Computed` staying active after first read until `close()`, single-isolate confinement).

## 1.0.0

Initial release.

Core:

- `Observable<T>` reactive value, plus `ObservableInt`, `ObservableDouble`, `ObservableBool`, `ObservableString`.
- `.obs` extension for creating observables from literals and collections.
- `ObservableList`, `ObservableMap`, `ObservableSet` reactive collections; reading any member tracks it, mutating any member notifies at most once per call — bulk operations (`addAll`, `removeWhere`, `retainWhere`, `insertAll`, `clear`, `sort`, `shuffle`) never notify once per element, and no-op mutations (adding a duplicate `Set` element, `removeWhere` that removes nothing, `map[k]=v` with an identical value, `clear()` on an already-empty collection) don't notify at all.
- `Observer` widget with automatic, stack-based dependency tracking and safe rebuild scheduling (no "defunct element" crashes).
- `ObserverValue` for self-contained local reactive state.
- `Computed<T>`: lazy, memoized derived values reusing the same dependency tracker as `Observer`; supports dynamic/conditional dependencies; only notifies when the derived value actually changes; `close()` unsubscribes from all current dependencies.
- `Observable.batch(() { ... })`: coalesces multiple writes inside the callback into a single notification per changed observable/collection for manual (`listen`/`ever`) subscribers, with nested-batch support.
- `equals` parameter on the `Observable<T>` constructor, for custom change-detection (e.g. floating-point tolerance) instead of `==`.
- `listen`/`ObservableSubscription`, stream-free manual subscriptions.
- Workers: `ever`, `once`, `debounce`, `interval`, plus `Worker`/`Workers`.

Robustness:

- An exception thrown inside one `ever`/`listen` callback does not stop other listeners of the same observable from running; it is reported via `FlutterError.reportError` (`library: 'all_observer'`) instead of being swallowed or propagating.
- A synchronous update cycle (a listener of A writing to B, whose listener writes back to A) stops after a bounded notification depth with a descriptive `FlutterError`, instead of crashing with a raw stack overflow.
- `Observer`: if the builder throws during a tracked build, dependency disposers accumulated up to that point are still assigned, so the next build/unmount does not leak or double-register listeners.
- The "write during build" warning covers both `Observable.value =` and reactive-collection mutations, and `ObserverConfig.strictMode` turns this case into a thrown `ObserverError` as well as the "empty Observer" case.
- `listen()`/`close()` on an already-`close()`d `Observable`/collection returns an inert (already-canceled) subscription instead of silently registering a listener that can never fire; a mutation attempted on a closed collection is a full no-op (the underlying data is left untouched), and double-`close()` is safe.
- Documented, in `Observable`'s dartdoc, that writing to an observable from a different isolate does not work (no cross-isolate synchronization is attempted).

Other:

- Debug-only, ANSI-colored logging via `ObserverConfig` and non-fatal misuse warnings (with optional `strictMode`).
- Zero external dependencies; full `ValueListenable` interoperability.

See `AUDIT_REPORT.md` at the repository root for the full item-by-item performance/robustness audit this release was validated against.
