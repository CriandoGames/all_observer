# Contributing to all_observer

Thanks for considering a contribution! This document covers the basics of
setting up, testing, and proposing changes.

## Setup

```bash
git clone https://github.com/CriandoGames/all_observer.git
cd all_observer
flutter pub get
```

The `example/` app has its own `pubspec.yaml` pointing at the package via a
`path:` dependency, so it always builds against your local checkout:

```bash
cd example
flutter pub get
flutter run
```

## Running tests

```bash
flutter test
```

Every new code path needs a test — this package has no CI gate that skips
coverage, and PRs without tests for new behavior will be asked to add them.
If you're fixing a bug, add a test that fails before your fix and passes
after, so the fix can't silently regress later.

## Style and lints

```bash
dart format --set-exit-if-changed .
flutter analyze
```

`analysis_options.yaml` enables `public_member_api_docs`: every public
class, method, getter, and field needs a dartdoc comment. This package's
convention is **bilingual dartdoc** — an English paragraph followed by a
Portuguese (pt-BR) translation of the same paragraph, separated by a blank
`///` line — for every public API. Look at any existing file (e.g.
`lib/src/observable/observable.dart`) for the exact pattern before writing
new docs.

## Design invariants

These are load-bearing for this package and PRs that violate them will be
asked to change approach, not just implementation:

- **Zero external dependencies.** `pubspec.yaml` depends on `flutter` (the
  SDK) and nothing else. Don't add a `dependencies:` entry for a pub.dev
  package, even a small one — vendor the tiny bit of logic you need
  instead, or open an issue to discuss first.
- **No breaking changes to the public API** without a major version bump
  and explicit discussion. New behavior should be additive (a new class, a
  new optional named parameter with a default that preserves the old
  behavior) or gated behind an `ObserverConfig` flag that defaults to the
  current behavior.
- **No `Stream`/`StreamController` inside the reactive core**
  (`lib/src/core/`). `listen()` and friends are built directly on the
  package's own `ListenerRegistry` — this keeps the core small and
  independently testable outside Flutter (`package:all_observer/core.dart`
  has zero `package:flutter` imports; keep it that way).
- **Friendly warnings by default, not exceptions.** Misuse (an `Observer`
  that reads nothing, a write during build, a write after `close()`) should
  warn via `ObserverLogger`/`ObserverInspector`, not throw — unless
  `ObserverConfig.strictMode` is `true`. If you're adding a new misuse
  check, follow that same pattern.
- **Glitch-free propagation.** If you touch `lib/src/core/batch_scope.dart`,
  `listener_registry.dart`, or `dependency_tracker.dart`, run (and if
  needed, extend) `test/observable/computed_graph_test.dart` — it exists
  specifically to hold the diamond/chained/cut-propagation/dynamic
  -dependency guarantees to their word. See `ARCHITECTURE.md` for why the
  graph is shaped the way it is before changing it.

## Proposing a change

1. Open an issue first for anything beyond a small bug fix or doc tweak —
   it saves everyone time if the approach is agreed on before code is
   written.
2. Keep PRs focused: one logical change per PR is easier to review than a
   bundle of unrelated fixes.
3. Update `CHANGELOG.md` under an `## Unreleased` heading describing what
   changed and why, in the same style as existing entries.
4. If your change affects public API surface, update `README.md` **and**
   `README.pt-BR.md` together — this package documents everything in both
   languages.

## Code of conduct

Be respectful and assume good faith. Disagreements about design are
welcome and expected — keep them focused on the tradeoffs, not the person.
