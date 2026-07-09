🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/async.md) | 🇺🇸 English

# Async state

`ObservableFuture<T>`, `ObservableStream<T>`, and the `AsyncState<T>`
(alias `AsyncValue<T>`) they're built on — race-safe async loading/data/error
state, with no `Stream` machinery required from you.

## `AsyncState<T>`

A plain sealed union with three cases: `AsyncLoading<T>`, `AsyncData<T>`,
`AsyncError<T>`. Consume it with `when`/`maybeWhen`, or the `isLoading`/
`hasData`/`hasError`/`valueOrNull` getters:

```dart
state.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (value) => Text('$value'),
  error: (error, stackTrace) => Text('Error: $error'),
);
```

`AsyncLoading.previousData` optionally carries the last known `AsyncData`
value — a stale-while-loading read, so a UI can keep showing previous
content (dimmed, overlaid) instead of a blank spinner during a refresh.

## `ObservableFuture<T>`

An `Observable<AsyncState<T>>` that runs a `Future<T> Function()` and
tracks its lifecycle automatically:

```dart
final userFuture = ObservableFuture<User>(() => api.fetchUser(id));

Observer(() => userFuture.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (user) => Text(user.name),
  error: (error, stackTrace) => Text('Error: $error'),
));

userFuture.refresh(); // re-runs futureFactory, e.g. for pull-to-refresh
```

`autoStart: true` by default — the future runs immediately on construction.
Pass `autoStart: false` to build without starting, and call `run()`
manually once you're ready:

```dart
final searchFuture = ObservableFuture<List<Result>>(
  () => api.search(query),
  autoStart: false,
);
// later, when the user submits:
searchFuture.run();
```

`refresh()` is just a more intention-revealing alias for `run()` — both
re-invoke `futureFactory`.

### Race safety

Every call to `run()`/`refresh()` bumps an internal generation counter. If
`futureFactory` is invoked again before an older call finishes, the older
call's eventual result — success or error — is silently discarded when it
arrives, instead of overwriting the newer state. The same guard discards a
still in-flight result if `close()` was called meanwhile. This means rapid
repeated refreshes (a user mashing a retry button, or a fast-typing search)
never show a stale result racing ahead of a fresher one.

## `ObservableStream<T>`

The `Stream` counterpart, with the same `AsyncState` contract:

```dart
final ticks = ObservableStream<int>(
  () => Stream.periodic(const Duration(seconds: 1), (i) => i),
);

Observer(() => ticks.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (n) => Text('$n'),
  error: (error, stackTrace) => Text('Error: $error'),
));
```

Every stream event becomes an `AsyncData` update; a stream error becomes
`AsyncError`. `refresh()` cancels the current subscription and starts a
fresh one from `streamFactory` — useful for reconnecting a socket/polling
stream after an error. Race safety works the same way as `ObservableFuture`
(generation counter), plus the previous `StreamSubscription` is explicitly
cancelled before resubscribing, so a stale subscription stops receiving
events altogether rather than relying only on the generation check.

If `streamFactory()` throws synchronously before returning a `Stream`, `run()`
converts it into `AsyncError`, matching `ObservableFuture`'s failure contract.
Asynchronous failures returned by `StreamSubscription.cancel()` are isolated
and forwarded through `CoreErrorReporting`, rather than becoming unhandled
asynchronous errors.

## Pull-to-refresh pattern

```dart
RefreshIndicator(
  onRefresh: () => userFuture.refresh(),
  child: Observer(() => userFuture.value.when(
    loading: (previousData) => previousData != null
        ? UserCard(user: previousData, dimmed: true)
        : const CircularProgressIndicator(),
    data: (user) => UserCard(user: user),
    error: (error, stackTrace) => ErrorView(error: error),
  )),
);
```

Using `previousData` during `loading` keeps the last-known content visible
(dimmed) while a refresh is in flight, instead of flashing a spinner over
already-loaded content.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Collections](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md) · Next: [Workers](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/workers.md)
