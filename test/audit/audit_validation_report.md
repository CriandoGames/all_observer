# all_observer audit validation report

## Baseline

- Baseline commit: `861325f42ce7419834102d4b13f044b25c2d1efb`
- Baseline library version: `1.5.4` (`pubspec.yaml` at baseline)
- Target patch release: `1.5.5`
- Flutter: `3.44.6` stable, framework `ee80f08bbf`
- Dart: `3.12.2` on `windows_x64`
- OS: Microsoft Windows 11 Pro `10.0.26200`, 64 bits
- `flutter pub get`: passed; dependency solver reported newer incompatible package versions only.
- Original `flutter analyze`: passed, `No issues found!`
- Original `flutter test`: passed, `372` tests, no pre-existing failures.
- Original measured duration: analyze command wall time `00:00:04.3526482`; test command wall time `00:00:13.5317892`.

## Added audit tests

| File | Tests |
| --- | ---: |
| `test/audit/computed_failure_test.dart` | 1 |
| `test/audit/effect_failure_test.dart` | 2 |
| `test/audit/batch_failure_test.dart` | 1 |
| `test/audit/async_close_test.dart` | 2 |
| `test/audit/collection_atomicity_test.dart` | 3 |

Total added audit tests: `9`.

## Results after correction

| ID | Hypothesis | Result | Test | Evidence | Severity | Flaky? |
| --- | --- | --- | --- | --- | --- | --- |
| A01 | Computed can retry after initial error | CORRIGIDA | `computed_failure_test.dart` | First read throws original `StateError`; second read recomputes and returns `41`; later dependency write returns `42`. | High | No |
| B01 | Effect throwing during creation can become inaccessible zombie | CORRIGIDA | `effect_failure_test.dart` | `effect()` still throws to caller, but changing the dependency does not run the body again and reports no later error. | High | No |
| B03 | Indirect invalidation in same flush can be lost | CORRIGIDA | `effect_failure_test.dart` | Chain converges through `seenByB == [0, 2, 4]`; final `source == 2`, `bridge == 4`, `doubled.value == 4`. | High | No |
| C01 | Batch throwing after mutation can leave divergent state | CORRIGIDA | `batch_failure_test.dart` | Direct source notifications remain discarded, but live `computed.value` reconciles to `2` on read instead of staying stale. | High | No |
| D01 | ObservableFuture.run after close starts async work | CORRIGIDA | `async_close_test.dart` | After `close()`, `run()` does not call the factory and emits no notification. | Medium | No |
| D02 | ObservableStream.run after close can subscribe | CORRIGIDA | `async_close_test.dart` | After `close()`, `run()` does not call the factory, does not listen, and emits no notification. | High | No |
| F01 | addAll with throwing iterable can partially mutate silently | CORRIGIDA | `collection_atomicity_test.dart` | Throwing iterable leaves list as `[10]`; no notification. | High | No |
| F02 | removeWhere throwing predicate can partially mutate silently | REFUTADA | `collection_atomicity_test.dart` | List remains `[1, 2, 3, 4]`; no notification. | Low | No, passed 3/3 |
| F03 | sort throwing comparator can corrupt/reorder silently | CORRIGIDA | `collection_atomicity_test.dart` | Throwing comparator leaves list as `[5, 4, 3, 2, 1]`; no notification. | High | No |

## Reproduction commands

Baseline and setup:

```bash
git rev-parse HEAD
flutter pub get
flutter analyze
flutter test
```

Audit tests:

```bash
flutter test test/audit/computed_failure_test.dart
flutter test test/audit/effect_failure_test.dart
flutter test test/audit/batch_failure_test.dart
flutter test test/audit/async_close_test.dart
flutter test test/audit/collection_atomicity_test.dart
flutter test test/audit/
```

Flakiness check used:

```powershell
for ($i = 1; $i -le 3; $i++) { Write-Output "AUDIT_RUN=$i"; flutter test test/audit }
```

Post-correction verification:

```bash
flutter test
flutter analyze
flutter test --coverage
```

## Post-correction verification

- `flutter test test/audit/`: passed, `9` tests.
- `flutter test test/regressions`: passed, `51` tests.
- `flutter test`: passed, `389` tests.
- `flutter test --coverage`: passed, `389` tests.
- `flutter analyze`: passed, `No issues found!`.

## Relevant production files

These production files are related to the corrected behaviors:

- `lib/src/core/core_computed.dart`
- `lib/src/core/dependency_tracker.dart`
- `lib/src/core/listener_registry.dart`
- `lib/src/effects/effect.dart`
- `lib/src/core/batch_scope.dart`
- `lib/src/core/core_observable.dart`
- `lib/src/observable/async/observable_future.dart`
- `lib/src/observable/async/observable_stream.dart`
- `lib/src/observable/collections/observable_list.dart`

## Notes

- Production code was changed after the validation phase to fix the P0 findings.
- Existing tests under `test/regressions/` were not modified; the confirmed
  audit scenarios were promoted into a new regression file.
- No assertions were weakened.
- The audit tests now assert the corrected behavior for the fixed hypotheses.
