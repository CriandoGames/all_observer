# all_observer 1.5.6 remaining risks validation

## Baseline

- Commit tested: `428ba3a559d04ecb0c4f5f6ca7557a274f6145ea`
- Baseline package version: `1.5.5`
- Target patch release: `1.5.6`
- Flutter: `3.44.6` stable, framework `ee80f08bbf`
- Dart: `3.12.2`
- `flutter pub get`: passed
- Baseline `flutter analyze`: passed, `No issues found!`
- Baseline `flutter test`: passed, `389` tests
- Existing suite result before these audit tests: passed

## Added audit tests

| File | Tests |
| --- | ---: |
| `test/audit/effect_same_registry_test.dart` | 3 |
| `test/audit/collection_exception_atomicity_test.dart` | 6 |
| `test/audit/observable_set_tracking_test.dart` | 4 |

Total added tests: `13`.

## Post-correction status

The confirmed hypotheses below were fixed after the validation phase.

- `flutter test test/audit/`: passed, `22` tests.
- `flutter test test/regressions`: passed, `54` tests.
- `flutter test`: passed, `405` tests.
- `flutter analyze`: passed, `No issues found!`.

Corrections applied:

- `effect()` consumes same-registry self-invalidation suppression once, so a
  later external write to the same observable in the same flush is observed.
- `ObservableSet.addAll()` materializes the iterable before mutating the set.
- `ObservableSet.toSet()` reports a reactive read before returning the copy.

## Summary table

| ID | Cenário | Resultado | Esperado | Observado | Severidade |
| --- | --- | --- | --- | --- | --- |
| E1.1 | Effect A writes `shared = 1`; direct listener B writes `shared = 2` in the same flush | CONFIRMADA | `shared == 2` and A observes `2` | `shared == 2`, but `seenByA == [0, 0]` | High |
| E1.2 | Effect A writes `shared = 1`; effect B writes `shared = 2` in the same flush | CONFIRMADA | `shared == 2` and A observes `2` | `shared == 2`, but `seenByA == [0, 0]` | High |
| E1.3 | Effect A writes `shared = 1`; `trigger -> Computed -> effect B` writes `shared = 2` | CONFIRMADA | `shared == 2` and A observes `2` | `shared == 2`, but `seenByA == [0, 0]` | High |
| C2.1 | `ObservableList.removeWhere` predicate throws at `4` | REFUTADA | Atomic, no notification | List intact, calls `4`, no exception-time notification, recovery notification works | Low |
| C2.2 | `ObservableList.retainWhere` predicate throws at `4` | REFUTADA | Atomic, no notification | List intact, calls `4`, no exception-time notification, recovery notification works | Low |
| C2.3 | `ObservableSet.addAll` iterable yields `1`, `2`, then throws | CONFIRMADA | Atomic, no notification | Set becomes `{10, 1, 2}` with no notification before recovery | High |
| C2.4 | `ObservableSet.removeWhere` predicate throws at `4` | REFUTADA | Atomic, no notification | Set intact, calls `4`, no exception-time notification, recovery notification works | Low |
| C2.5 | `ObservableSet.retainWhere` predicate throws at `4` | REFUTADA | Atomic, no notification | Set intact, calls `4`, no exception-time notification, recovery notification works | Low |
| C2.6 | `ObservableMap.removeWhere` predicate throws at key `3` | REFUTADA | Atomic, no notification | Map intact, calls `3`, no exception-time notification, recovery notification works | Low |
| S3.1 | `Computed` reads only `ObservableSet.toSet()` | CONFIRMADA | After `source.add(3)`, derived value becomes `3` | Source has `{1, 2, 3}`, derived remains `2` | High |
| S3.2 | `effect` reads only `ObservableSet.toSet()` | CONFIRMADA | Effect runs twice and records `{1, 2, 3}` | Effect runs once and warns that it read no observable | High |
| S3.3 | Positive controls vs `toSet()` | CONFIRMADA | `toSet()` invalidates like `length`, `contains`, iteration, and `toList()` | Positive controls update; `toSet()` computed remains `2` | High |
| S3.4 | `toSet()` copy independence | REFUTADA | Mutating copy does not change source | Copy becomes `{1, 2, 999}` and source remains `{1, 2}` | Low |

## Confirmed hypotheses

### E1.1 Direct listener external write

- Test: `Audit 1 - own and external writes to the same registry direct listener external write is not suppressed as own write`
- Reproduction: `flutter test test/audit/effect_same_registry_test.dart`
- Failure: expected `seenByA` to contain `2`; actual `[0, 0]`
- Observed sequence: `seenByA == [0, 0]`
- Executions: A ran `2` times, inferred from `seenByA.length`; B performed the external write and final `shared.value == 2`
- Final state: `trigger == 1`, `shared == 2`
- Determinism: deterministic, failed `3/3`
- Impact: effect consumers can remain at the intermediate value even though the shared observable reached the final external value
- Related production files: `lib/src/effects/effect.dart`, `lib/src/core/dependency_tracker.dart`, `lib/src/core/listener_registry.dart`
- Minimal reproduction: effect A reads `trigger` and `shared`, writes `shared = 1`; direct listener on `shared` writes `shared = 2`

### E1.2 External write from another effect

- Test: `Audit 1 - own and external writes to the same registry other effect external write is not suppressed as own write`
- Reproduction: `flutter test test/audit/effect_same_registry_test.dart`
- Failure: expected `seenByA` to contain `2`; actual `[0, 0]`
- Observed sequence: `seenByA == [0, 0]`
- Executions: A ran `2` times, inferred from `seenByA.length`; B ran at least through initial tracking and the `shared == 1` reaction
- Final state: `trigger == 1`, `shared == 2`
- Determinism: deterministic, failed `3/3`
- Impact: indirect state normalization done by another effect can be missed by an already-subscribed effect
- Related production files: `lib/src/effects/effect.dart`, `lib/src/core/dependency_tracker.dart`, `lib/src/core/listener_registry.dart`
- Minimal reproduction: effect A reads and writes `shared`; effect B reads `shared` and rewrites `1 -> 2`

### E1.3 External write from `trigger -> Computed -> effect`

- Test: `Audit 1 - own and external writes to the same registry computed chain external write is not suppressed as own write`
- Reproduction: `flutter test test/audit/effect_same_registry_test.dart`
- Failure: expected `seenByA` to contain `2`; actual `[0, 0]`
- Observed sequence: `seenByA == [0, 0]`
- Executions: A ran `2` times, inferred from `seenByA.length`; B was triggered by the computed chain
- Final state: `trigger == 1`, `shared == 2`
- Determinism: deterministic, failed `3/3`
- Impact: same-flush graph chains can produce a final value that one effect never observes
- Related production files: `lib/src/effects/effect.dart`, `lib/src/core/dependency_tracker.dart`, `lib/src/core/listener_registry.dart`
- Minimal reproduction: effect A reads `trigger` and `shared`, writes `shared = 1`; effect B reads `Computed(() => trigger.value)` and writes `shared = 2`

### C2.3 `ObservableSet.addAll` throwing iterable

- Test: `Audit 2 - collection exception atomicity ObservableSet.addAll is atomic when iterable throws`
- Reproduction: `flutter test test/audit/collection_exception_atomicity_test.dart`
- Failure: expected `{10}`; actual `{10, 1, 2}`
- Observed sequence: iterable yielded `1`, `2`, then threw `StateError`
- Calls and notifications: `moveNextCalls == 3`; no notification before recovery
- Final state after exception: set contains `{10, 1, 2}`
- Recovery: adding `99` notifies and dependent computed converges again
- Classification: PARCIAL SILENCIOSA
- Determinism: deterministic, failed `3/3`
- Impact: consumers can observe stale derived state while the set has already been partially mutated
- Related production file: `lib/src/observable/collections/observable_set.dart`
- Minimal reproduction: `ObservableSet<int>({10}).addAll(Iterable` that yields `1`, `2`, then throws)

### S3.1 `Computed` using only `toSet()`

- Test: `Audit 3 - ObservableSet.toSet tracking Computed based exclusively on toSet reacts to mutations`
- Reproduction: `flutter test test/audit/observable_set_tracking_test.dart`
- Failure: expected derived value `3`; actual `2`
- Observed sequence: first read `2`; after `source.add(3)`, source is `{1, 2, 3}` but derived remains `2`
- Executions: `computations` remains `1`
- Final state: source contains `{1, 2, 3}`
- Determinism: deterministic, failed `3/3`
- Impact: computed values based only on `toSet()` do not subscribe to the set
- Related production file: `lib/src/observable/collections/observable_set.dart`
- Minimal reproduction: `Computed(() => source.toSet().length)` followed by `source.add(3)`

### S3.2 `effect` using only `toSet()`

- Test: `Audit 3 - ObservableSet.toSet tracking effect based exclusively on toSet reacts to mutations`
- Reproduction: `flutter test test/audit/observable_set_tracking_test.dart`
- Failure: expected `runs == 2`; actual `1`
- Observed sequence: `seen == [{1, 2}]`; after mutation, no `{1, 2, 3}` snapshot is recorded
- Warning: `Effect(auditSetToSetEffect) não leu nenhum observável no corpo. Ele nunca vai re-executar.`
- Final state: source contains `{1, 2, 3}`
- Determinism: deterministic, failed `3/3`
- Impact: effects based only on `toSet()` never re-run
- Related production file: `lib/src/observable/collections/observable_set.dart`
- Minimal reproduction: `effect(() => seen.add(source.toSet()))` followed by `source.add(3)`

### S3.3 Positive controls vs `toSet()`

- Test: `Audit 3 - ObservableSet.toSet tracking toSet invalidates like positive ObservableSet read controls`
- Reproduction: `flutter test test/audit/observable_set_tracking_test.dart`
- Failure: expected `byToSet.value == 3`; actual `2`
- Observed sequence: controls based on `length`, `contains`, iteration, and `toList()` update after `source.add(3)`; `toSet()` does not
- Final state: source contains `{1, 2, 3}`
- Determinism: deterministic, failed `3/3`
- Impact: confirms the reactive mechanism works in the same environment and isolates the gap to `toSet()`
- Related production file: `lib/src/observable/collections/observable_set.dart`
- Minimal reproduction: compare `Computed(() => source.length)` with `Computed(() => source.toSet().length)`

## Refuted hypotheses

- `ObservableList.removeWhere` remained atomic when the predicate threw.
- `ObservableList.retainWhere` remained atomic when the predicate threw.
- `ObservableSet.removeWhere` remained atomic when the predicate threw.
- `ObservableSet.retainWhere` remained atomic when the predicate threw.
- `ObservableMap.removeWhere` remained atomic when the predicate threw.
- `ObservableSet.toSet()` returns an independent copy; mutating the copy does not mutate the source.

## SDK-dependent observations

- Predicate atomicity for `List.removeWhere`, `List.retainWhere`,
  `Set.removeWhere`, `Set.retainWhere`, and `Map.removeWhere` depends on the
  current Dart collection implementations. These results were observed on
  Dart `3.12.2`.
- The partial mutation in `ObservableSet.addAll` follows Dart `Set.addAll`
  consuming the iterable incrementally before the iterable throws.

## Execution results

Isolated commands:

```bash
flutter test test/audit/effect_same_registry_test.dart
flutter test test/audit/collection_exception_atomicity_test.dart
flutter test test/audit/observable_set_tracking_test.dart
```

Flakiness check:

```powershell
for ($i = 1; $i -le 3; $i++) { flutter test test\audit\effect_same_registry_test.dart }
for ($i = 1; $i -le 3; $i++) { flutter test test\audit\collection_exception_atomicity_test.dart }
for ($i = 1; $i -le 3; $i++) { flutter test test\audit\observable_set_tracking_test.dart }
```

Observed result: all confirmed failures reproduced in every run.

Final commands:

```bash
flutter test test/audit/
flutter test
flutter analyze
```

- `flutter test test/audit/`: failed with `15` passed and `7` failed.
- `flutter test`: failed with `395` passed and `7` failed.
- `flutter analyze`: passed, `No issues found!`.

## Notes

- This validation did not change production code.
- No files under `lib/` were modified.
- All added resources are under `test/audit/`.
- No tests were skipped.
