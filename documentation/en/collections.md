🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md) | 🇺🇸 English

# Reactive collections

`ObservableList<E>`, `ObservableMap<K, V>`, `ObservableSet<E>` — drop-in
reactive replacements for `List`/`Map`/`Set`.

## Read contract

Each behaves exactly like its built-in counterpart for every read —
`length`, `[]`, `contains`, iteration — because they extend `ListBase`/
`MapBase`/`SetBase` respectively. Any read inside a tracked builder
registers the collection as a dependency, same as reading `.value` on a
plain `Observable`.

```dart
final items = <String>[].obs; // ObservableList<String>

Observer(() => Text('${items.length} items'));
```

## Notification contract

Every mutating member notifies **at most once per call**, never once per
element:

```dart
items.add('one');                     // notifies once
items.addAll(['two', 'three']);       // still once, not three times
items.removeWhere((e) => e == 'two'); // once, and only if something matched
```

A no-op mutation notifies **zero** times:

- Adding a `Set` element that's already present.
- `removeWhere`/`retainWhere` that matches nothing.
- Assigning an identical value to an existing `Map` key.

This matters for `Observer`/`Computed` performance: a bulk operation on a
large collection is a single rebuild, not one per element, and a mutation
that changes nothing produces no rebuild at all.

## Examples

```dart
final tags = <String>{}.obs;      // ObservableSet<String>
Observer(() => Text('${tags.length} tags'));
tags.add('flutter');
tags.add('flutter'); // no-op, no notification — already present

final scores = <String, int>{}.obs; // ObservableMap<String, int>
Observer(() => Text('${scores['carlos'] ?? 0}'));
scores['carlos'] = 10;
scores['carlos'] = 10; // no-op, same value already there
```

## The one pitfall: mutating an element in place

Reactive collections track *membership and structure* (what's in the
collection, and how many), not the internal state of the objects inside it.
Mutating an object already stored in the collection does not notify on its
own:

```dart
final tasks = <Task>[].obs;
tasks.add(Task(done: false));

tasks.first.done = true; // mutates the Task object directly — no notification
tasks.refresh();          // force it, same as on a plain Observable
```

Call `refresh()` (inherited from `Observable`) after mutating an object
in place, exactly as you would for a plain `Observable<T>` holding a
mutable object.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Core concepts](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md) · Next: [Async](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/async.md)
