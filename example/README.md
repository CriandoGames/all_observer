# all_observer example

A small Flutter app demonstrating every major `all_observer` feature: a
counter driving a memoized `Computed`, a debounced search field, an
`ObservableFuture` async fetch with retry, a form saved via `Observable
.batch`, and `Observable<T>` interoperating directly with Flutter's own
`ValueListenableBuilder`. Business logic lives in small controller classes
under
[`lib/controllers/`](https://github.com/CriandoGames/all_observer/tree/main/example/lib/controllers),
each constructible with an injectable dependency and a default — the same
pattern this project recommends for testable widgets.

## Running the tests

The tests under
[`test/`](https://github.com/CriandoGames/all_observer/tree/main/example/test)
are real, runnable examples of how to test code built on `all_observer`:
widget tests, pure-Dart unit tests, a rebuild-granularity proof, debounced
worker tests using virtual time, deterministic async tests via injected
fakes, and `strictMode` misuse detection. Run them with:

```
cd example
flutter test
```

See [`documentation/en/testing.md`](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md)
(or the [pt-BR version](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md))
for a guided walkthrough of each test file.
