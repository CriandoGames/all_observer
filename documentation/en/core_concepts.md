🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md) | 🇺🇸 English

# Core concepts

`Observable`, `Observer`, dependency tracking, and `Computed` — the reactive
core everything else in `all_observer` is built on.

## The mental model: automatic dependency tracking

Every `Observable<T>` (and its subclasses — `Computed`, `ObservableFuture`,
collections) holds a value and a set of listeners. When you read `.value`
inside an `Observer` builder, an `effect()`, or a `Computed`'s compute
function, that read is registered against a `DependencyTracker` stack — the
currently running tracked callback subscribes itself to the observable's
registry automatically. There is no separate declaration step: reading *is*
subscribing.

Dependencies are **re-discovered on every run**. An `Observer` clears its
previous subscriptions before rebuilding, then tracks whatever the builder
reads this time. This means conditional branches work correctly out of the
box:

```dart
Observer(() => isLoggedIn.value ? Text(user.value.name) : const LoginButton());
```

When `isLoggedIn` is `false`, this `Observer` depends only on `isLoggedIn` —
`user` is never read, so a change to `user` while logged out causes no
rebuild. The moment `isLoggedIn` flips to `true` and the widget rebuilds,
`user` becomes a tracked dependency too.

The same rule applies to `effect()`: every run replaces the previous
dependency set with what the callback read this time. Effects are scheduled
at most once per batch flush, and a write made by the effect itself during
that flush does not trigger a duplicate self-run. A later external write to
one of its tracked dependencies still schedules the next run normally.

## `Observable<T>`

Create one with `.obs` (`0.obs`, `'hi'.obs`, `false.obs`, `9.99.obs`,
`<String>[].obs`) or the constructor directly for custom types:

```dart
final user = Observable<User?>(null, name: 'user');
```

`name` is optional and only used in debug logs/warnings — when omitted, a
short hash-based label is used instead.

Reading and writing:

```dart
final count = 0.obs;
print(count.value); // read
count.value = 1;    // write — notifies only if 1 != 0
```

A write only notifies listeners when the new value differs from the current
one via `==`. There's no special case for the first assignment — the rule
is always "did it change".

### `refresh()`

For mutable objects whose internal state changed without replacing the
reference (e.g. mutating a field on an object held by the observable),
`==` won't detect a difference because the reference is identical. Call
`refresh()` to force a notification:

```dart
final settings = Observable<Settings>(Settings());
settings.value.darkMode = true; // mutates in place, no notification yet
settings.refresh(); // now listeners are notified
```

### Custom `equals`

```dart
final price = Observable<double>(9.99, equals: (a, b) => (a - b).abs() < 0.01);
```

Overrides the default `==` comparison — useful for floating-point
tolerances, or comparing only part of a larger object.

### `listen()`

Subscribe without an `Observer` widget:

```dart
final sub = count.listen((value) => print('now $value'), immediate: false);
sub.cancel();
```

Pass `when: (value) => value > 0` to only invoke the callback while the
predicate holds — a plain `if` guard, no extra tracking involved.

### `close()`

Disposes the observable: removes all listeners and marks it closed.
Subsequent writes are ignored with a debug warning instead of crashing.
Always `close()` an `Observable`/`Computed`/collection you created manually
once you're done with it (e.g. in a `State.dispose()`).

## `Observer`

```dart
Observer(() => Text('${count.value}'));
```

Rebuilds automatically whenever any observable read inside `builder`
changes. Rebuilds are coalesced per frame — multiple dependency changes in
the same frame trigger one rebuild, not one per change — and guarded
against already-unmounted widgets.

An `Observer` that reads no observable will never rebuild; this is treated
as a likely mistake and produces a debug warning (or throws, under
`strictMode` — see [advanced.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md)).

### `Observer.withChild`

For a static child subtree that doesn't depend on any observable:

```dart
Observer.withChild(
  builder: (context, child) => Row(children: [Text('${count.value}'), child]),
  child: const ExpensiveStaticWidget(),
);
```

`child` is built once and passed back into `builder` on every rebuild
instead of being reconstructed — the same technique `child` parameters
solve elsewhere in Flutter.

## `Computed<T>`

A read-only derived value, lazy and memoized:

```dart
final firstName = 'Carlos'.obs;
final lastName = 'Castro'.obs;
final fullName = Computed(() => '${firstName.value} ${lastName.value}');
Observer(() => Text(fullName.value)); // recomputes only when needed
```

`compute` never runs before the first read of `.value`. Subsequent reads
return the cached result until a dependency notifies. A recompute only
notifies its own listeners if the new value actually differs (`==`, or a
custom `equals`) from the previous one — a dependency changing without
affecting the derived result causes no downstream rebuild.

`Computed` reuses the exact same `DependencyTracker` `Observer` uses, so
conditional/dynamic dependencies inside `compute` work identically. Call
`close()` once you're done with a manually-created `Computed` — it stays
subscribed to its dependencies indefinitely otherwise (see
[Known limitations](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md)).

### `select`

Sugar for a narrower `Computed` derived from a single `Observable`:

```dart
final user = Observable<User>(User(name: 'Carlos', age: 30));
final userName = user.select((u) => u.name); // == Computed(() => user.value.name)
```

The caller owns the returned `Computed` and must `close()` it.

## `ValueListenable` interop

Every `Observable<T>` (and `Computed<T>`) implements `ValueListenable<T>`,
so it plugs directly into anything that already speaks that interface:

```dart
ValueListenableBuilder<int>(
  valueListenable: count,
  builder: (context, value, _) => Text('$value'),
);

AnimatedBuilder(animation: Listenable.merge([count, otherObservable]), ...);
```

## Guided tutorial: from counter to a small task list

Starting from the README's counter, here's a slightly larger example that
uses `Computed` for a derived summary, and closes everything on `dispose()`:

```dart
class _TaskListState extends State<TaskList> {
  final ObservableList<Task> _tasks = <Task>[].obs;
  late final Computed<String> _summary;

  @override
  void initState() {
    super.initState();
    _summary = Computed(() {
      final int done = _tasks.where((t) => t.done).length;
      return '$done of ${_tasks.length} done';
    });
  }

  @override
  void dispose() {
    _tasks.close();
    _summary.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Observer(() => Text(_summary.value)),
        Expanded(
          child: Observer(
            () => ListView(
              children: _tasks
                  .map((t) => CheckboxListTile(
                        value: t.done,
                        title: Text(t.title),
                        onChanged: (v) => t.done = v ?? false,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
```

`_summary` only recomputes when `_tasks` notifies (an add/remove/mutation),
and only rebuilds the `Observer` above it if the resulting string actually
changed.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Next: [Collections](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md)
