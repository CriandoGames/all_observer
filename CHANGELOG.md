## 1.0.0

Initial release.

- `Observable<T>` reactive value, plus `ObservableInt`, `ObservableDouble`, `ObservableBool`, `ObservableString`.
- `.obs` extension for creating observables from literals and collections.
- `ObservableList`, `ObservableMap`, `ObservableSet` reactive collections.
- `Observer` widget with automatic, stack-based dependency tracking and safe rebuild scheduling (no "defunct element" crashes).
- `ObserverValue` for self-contained local reactive state.
- `listen`/`ObservableSubscription`, stream-free manual subscriptions.
- Workers: `ever`, `once`, `debounce`, `interval`, plus `Worker`/`Workers`.
- Debug-only, ANSI-colored logging via `ObserverConfig` and non-fatal misuse warnings (with optional `strictMode`).
- Zero external dependencies; full `ValueListenable` interoperability.
