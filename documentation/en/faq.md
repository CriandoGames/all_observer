🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/faq.md) | 🇺🇸 English

# FAQ

## Do I need to call `close()` on every observable?

For anything you create manually and hold as a field (an `Observable`,
`Computed`, `ObservableList`/`Map`/`Set`, `ObservableFuture`/`Stream`,
`ObservableHistory`), yes — call `close()`/`dispose()` when you're done
with it, typically in `State.dispose()`. `Computed` in particular stays
subscribed to its dependencies indefinitely until closed (see
[Known limitations](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md)).
`Observer`/`ObserverValue` widgets clean up their own tracking
subscriptions automatically when unmounted — you don't manage those.

## Why doesn't my `Observer` rebuild?

The two most common causes:

1. **You read the observable outside the builder.** Only reads that happen
   *during* the `Observer`'s `builder()` call are tracked — reading
   `.value` before constructing the `Observer`, or caching it in a local
   variable computed outside the builder, doesn't count.
2. **You mutated an object in place without calling `refresh()`.** If the
   observable holds a mutable object and you changed a field on it directly
   (rather than assigning a new value), `==` sees the same reference and
   doesn't notify — call `refresh()` after the mutation.

An `Observer` that reads nothing at all also produces a debug warning
("never going to rebuild") to help catch this class of mistake early.

## Can I use `all_observer` alongside Provider/Riverpod/Bloc?

Yes. `all_observer` has no global registration and no opinion on where
your state lives — wrap an `Observable` inside a `Provider`/`Notifier`/
`Bloc` you already manage, or use it standalone next to them. It composes
rather than competes.

## Does it work on Web/desktop?

Yes — the reactive core has no platform-specific code. `Observer` is a
plain `StatefulWidget`, so it works anywhere Flutter widgets do.

## How do I test code that uses `all_observer`?

`Observable`/`Computed` are plain Dart objects — read/write/assert on them
directly in `test`/`flutter_test`, no `pumpWidget` required unless you're
testing an actual `Observer`. See the dedicated
[Testing guide](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md)
for widget tests, unit tests, `strictMode`, and worker/async testing tips —
every example there is a real test from
[`example/test/`](https://github.com/CriandoGames/all_observer/tree/main/example/test).

## What's the difference between `Observer` and `ValueListenableBuilder`?

`Observable<T>` *is* a `ValueListenable<T>`, so `ValueListenableBuilder`
works with it directly — but it only tracks the one `valueListenable` you
pass in. `Observer` auto-discovers *every* observable read inside its
builder, including several at once and conditional/dynamic reads, with no
need to declare them up front.

## Is `batch()` obligatory?

No. Since v1.2.0, every write is automatically glitch-free — diamond
dependency graphs recompute correctly without it. `batch()` remains useful
purely to *coalesce* notifications to manual (`listen`/`ever`) subscribers
when you write to several observables in one logical action. See
[Advanced](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md).

## Is it production-ready? How many tests does it have?

225 tests as of v1.3.0, covering the core dependency tracker, `Computed`
diamond/cycle scenarios, collections' notify-at-most-once contract, async
race safety, workers, and the debug logging/inspector system. See
`ARCHITECTURE.md` in the repository root for the design rationale behind
the glitch-free guarantee specifically.

## What happens if an exception is thrown inside a listener/effect/inspector?

It's isolated: an exception thrown by one listener never stops other
listeners of the same observable from running (each is wrapped in its own
`try`/`catch`), and the same isolation applies to `ObserverInspector`
implementations. A synchronous update cycle (A's listener writes B, B's
listener writes A, ...) is stopped after a bounded notification depth with
a descriptive `ObserverCycleError`, instead of a raw stack overflow.

## Can I use it outside Flutter (a CLI tool, a server)?

Yes, via `package:all_observer/core.dart` — `CoreObservable`, `CoreComputed`,
and the rest of the engine have zero `package:flutter` import. See
[Advanced](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md#packageall_observercoredart--the-pure-dart-engine).

## Does it work across isolates?

No — like the rest of Dart, every `Observable`/`Computed`/collection is
confined to the isolate that created it. Use `SendPort`/`ReceivePort` or
`compute` to move data between isolates and write back to the observable
on its own isolate.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Migrating from GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/migration_from_getx.md) · Next: [Tutorials](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/tutorials.md)
