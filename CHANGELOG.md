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
