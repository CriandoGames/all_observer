🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/workers.md) | 🇺🇸 English

# Workers

`ever`, `once`, `debounce`, `interval` — the recommended way to run
non-widget side effects (network calls, analytics, persistence) off an
observable change, instead of sprinkling `addListener` calls by hand.

Each returns a `Worker` with a `dispose()` method; group several with
`Workers([...]).dispose()`.

## `ever` — run on every change

```dart
final count = 0.obs;
final everWorker = ever(count, (int value) => print('count is now $value'));
```

A manual listener with a friendlier name — runs the callback with the new
value every time `count` changes. `dispose()` cancels it.

## `once` — run a single time, then self-dispose

```dart
final isLoggedIn = false.obs;
once(isLoggedIn, (bool value) {
  if (value) analytics.logLogin();
});
```

Fires exactly once, on the first change, then automatically stops
listening — no need to keep a reference to dispose it yourself (though the
returned `Worker` can still be disposed early if the event never fires).

## `debounce` — run after changes settle

```dart
final query = ''.obs;
final search = debounce(query, (String value) {
  runSearch(value);
}, time: const Duration(milliseconds: 400));
```

Runs 400ms after the *last* change — perfect for search-as-you-type. Every
new change resets the timer; the callback only fires once the value has
stopped changing for the full duration. The internal `Timer` is cancelled
on `dispose()`.

## `interval` — run at most once per duration

```dart
final scrollOffset = 0.0.obs;
final saveScroll = interval(scrollOffset, (double value) {
  saveScrollPosition(value);
}, time: const Duration(seconds: 1));
```

Fires immediately on the first change, then at most once per `time` while
the observable keeps changing — the latest value at the end of each
cooldown window is what gets delivered (a trailing-edge flush), not every
intermediate value. Good for throttling something like scroll-position
persistence that would otherwise fire on every frame.

## Grouping and disposal

```dart
final debounceWorker = debounce(query, runSearch, time: const Duration(milliseconds: 400));
final everWorker = ever(count, (int value) => print(value));
final intervalWorker = interval(scrollOffset, saveScrollPosition, time: const Duration(seconds: 1));

Workers([debounceWorker, everWorker, intervalWorker]).dispose();
```

`once` disposes itself after firing; `debounce`/`interval` cancel their
internal `Timer` on `dispose()` so nothing fires after you're done with
them — always dispose workers you keep a reference to (typically in
`State.dispose()`, ideally via `ObserverStateMixin.autoDispose` — see
[advanced.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md)).

## Real examples

```dart
// Analytics: fire once when a session actually starts.
once(isLoggedIn, (bool v) { if (v) analytics.logSessionStart(); });

// Autosave: wait for the user to stop typing before hitting disk.
final autosave = debounce(draftText, (String text) => storage.save(text),
    time: const Duration(seconds: 2));

// Search-as-you-type: debounce the query, not every keystroke.
final liveSearch = debounce(searchQuery, (String q) => repository.search(q),
    time: const Duration(milliseconds: 300));
```

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Async](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/async.md) · Next: [Advanced](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md)
