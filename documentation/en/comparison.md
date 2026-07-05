🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/comparison.md) | 🇺🇸 English

# How `all_observer` compares

A factual, non-marketing comparison against other Flutter/Dart reactivity
approaches. None of these are "bad" — they solve for different priorities.
Claims about other libraries here are limited to what's documented in their
own official docs; where uncertain, this stays general rather than
specific.

| | `all_observer` | GetX | Riverpod | Bloc | MobX | signals |
|---|---|---|---|---|---|---|
| External dependencies | Zero | Zero (itself is all-in-one) | `riverpod`, often `flutter_riverpod`/`riverpod_generator` | `bloc`, `flutter_bloc` | `mobx`, `mobx_codegen`, `build_runner` | Zero |
| Code generation | None | None | Optional (`riverpod_generator`), common in practice | None | Required (`build_runner`) for `@observable`/`@computed`/`@action` | None |
| Dependency injection | None (compose with your own) | Built-in (`Get.put`/`Get.find`) | Built-in (provider graph) | None (compose with your own) | None | None |
| Routing | None | Built-in (`Get.to`, named routes) | None | None | None | None |
| Scope | Reactive values + widget rebuilding only | State + routing + DI + snackbars/dialogs (a full framework) | State + DI (provider graph), no routing/UI helpers | Event/state architecture (BLoC pattern) | Reactive values + actions/reactions, no DI/routing | Reactivity only, multi-platform (not Flutter-specific) |
| Dependency tracking | Auto (read `.value` during build/`effect()`/`Computed`) | Auto, via `Obx`/`GetX` reading `.value`/`.obs` | Auto, via `ref.watch` inside a `Provider`/`Notifier` | Manual (explicit events → state transitions) | Auto, via `Observer`/reactions reading `@observable` fields | Auto, via signal reads inside an effect/computed |
| Async primitives | `ObservableFuture`/`ObservableStream` (race-safe, generation-counter) | `.obs` + manual async handling | `FutureProvider`/`StreamProvider` | Async event handlers (`on<Event>` with `emit`) | Reactions over async actions | Depends on platform bindings |
| Diamond-dependency glitches | Prevented by design (two-phase flush, `ARCHITECTURE.md`) | Not a documented guarantee | N/A (providers don't form a `Computed`-chain graph the same way) | N/A (state machine, not a dependency graph) | Prevented by MobX's own reactive core | Prevented by design (its core selling point) |
| Testability | Plain Dart objects, no widget needed for most tests | `Get.testMode`, widget tests for `Obx` | `ProviderContainer` for unit tests | Well-established (`bloc_test`, `blocTest`) | Plain reactive objects, unit-testable | Plain objects, unit-testable |
| Learning curve | Low | Low | Medium | Medium–high | Medium | Low |
| API surface size | Small (`Observable`, `Observer`, `Computed`, workers, async, collections) | Large (state+DI+routing+utils) | Medium–large (providers, notifiers, modifiers) | Medium (events, states, bloc/cubit) | Medium (observables, actions, reactions, codegen) | Small |

## GetX

An all-in-one framework: state management, dependency injection, and
routing in a single package with almost no boilerplate. Best choice when
you want one library to own your entire app architecture and are fine with
its conventions. `all_observer` covers only the reactive-state slice of
what GetX does — see [migration_from_getx.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/migration_from_getx.md)
if you're moving away from GetX's state layer while keeping (or replacing
separately) its DI/routing.

## Riverpod

A compile-time-checked provider graph with strong DI story and no
`BuildContext` dependency for reading state. Best choice when you want the
compiler to catch a missing/misconfigured provider before runtime, and you
don't mind the provider-declaration ceremony (and, in most real projects,
a code generator). `all_observer` has no provider graph or DI layer at all
— you compose it with whatever DI approach you already use.

## Bloc

An explicit, auditable event → state architecture, popular in larger teams
that value a strict separation between "what happened" (events) and "what
the UI shows" (states), plus first-class testing tooling (`bloc_test`).
Best choice when auditability and a strict unidirectional flow matter more
than minimizing boilerplate. `all_observer` has no event layer — state
changes are direct value writes, not dispatched events.

## MobX

A mature, decorator-based reactive core (`@observable`, `@computed`,
`@action`) with its own dev tools, requiring `build_runner` codegen. Best
choice if you're already invested in its vocabulary and codegen step, or
want its action/reaction-tracing tools. `all_observer` reaches for the same
kind of automatic dependency tracking without any code generation step.

## signals

The closest philosophical relative: zero-dependency, glitch-free reactivity
with a small API surface. `signals` is multi-platform Dart (not
Flutter-specific) with a browser DevTools extension in its ecosystem.
`all_observer` is Flutter-first (with `package:all_observer/core.dart` as
its own pure-Dart escape hatch) and ships an `Observer` widget, reactive
collections, and race-safe async primitives out of the box as part of the
same package.

## Why choose `all_observer`

Reach for it when you want reactive state and nothing else: no DI
container to learn, no routing convention to adopt, no code generator in
your build pipeline, and no risk of a transitive dependency going stale or
unmaintained, because there isn't one. The same primitive scales from a
single counter to a `Computed` graph, race-safe async state, and pluggable
observability, without switching vocabulary partway through. It composes
with (rather than replaces) GetX's routing/DI, Riverpod's provider graph,
Bloc's event architecture, or a hand-rolled controller class, since
`all_observer` has no opinion on where state *lives* — only on how it
*notifies*.

Reach for something else when you specifically need what that something
else specializes in: GetX's all-in-one routing+DI+state if you want one
framework for everything; Riverpod if you want a compile-time-checked DI
graph; Bloc if your team values an auditable event/state architecture at
scale; MobX if you're already invested in its action/reaction vocabulary;
`signals` if you need the same reactive model outside Flutter entirely.

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [Testing](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md) · Next: [Migrating from GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/migration_from_getx.md)
