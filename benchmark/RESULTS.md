# Benchmark results

`performance_guard_test.dart` now runs deterministic, broad relative guards
in CI for scalar `Observable` overhead and `ObservableList.addAll`. These are
debug-mode catastrophe guards, not release-performance targets.

The Observer Protocol matrix was executed on 2026-07-18 with Flutter 3.44.6
and Dart 3.12.2 on Windows x64. Absolute timings remain machine-specific;
the checked-in guard uses broad median ratios to avoid machine-sensitive CI
failures. Heap allocations could not be measured reliably with the available
Stopwatch harness and remain a residual measurement gap.

## Observer Protocol v1 matrix

| Scenario | µs/op |
| --- | ---: |
| disabled | 0.0348 |
| enabled, no consumer | 0.4097 |
| one empty consumer | 1.1139 |
| five empty consumers | 3.7738 |
| registry + buffer 0 | 0.4046 |
| registry disabled + buffer 0 | 0.3759 |
| registry + buffer 1 | 0.4084 |
| registry + buffer 1,000 | 0.4151 |
| registry + buffer 100,000 | 0.5405 |
| capture values | 0.4376 |
| capture stack | 1.2729 |
| node create/dispose churn | 1.7702 |

A 1,000-dependency replacement measured 703.168 µs/run; a snapshot of 1,000
nodes measured 69.632 µs/snapshot. Run the individual Flutter benchmarks with:

```
flutter test benchmark/observable_vs_value_notifier_benchmark.dart
flutter test benchmark/observer_rebuild_cost_benchmark.dart
flutter test benchmark/observable_list_addall_benchmark.dart
```

and replace the placeholders below with the real numbers from your
machine. Absolute numbers vary a lot by hardware; what matters most is the
**ratio** between `Observable` and the baseline it's compared against.

## `observable_vs_value_notifier_benchmark.dart`

Compares `Observable<int>` set+get against a plain `ValueNotifier<int>`,
outside any tracking context (2,000,000 iterations).

| Metric | Result |
|---|---|
| `ValueNotifier<int>` total | not executed |
| `Observable<int>` total | not executed |
| Overhead ratio (target: ≤2x) | not executed |

Expected shape of the result based on a static read of the code: each
`Observable.value` read does one extra call
(`DependencyTracker.reportRead`) that bails out immediately via a
null-check on the tracking stack (`_stack.isEmpty ? null : _stack.last`)
when no context is active — no allocation on that path. Each write does an
`==`/custom `equals` comparison plus (outside `kDebugMode`) no logging.
The expected overhead is small (a handful of extra method calls per
op), comfortably under a 2x target, but this must be confirmed by an
actual run.

## `observer_rebuild_cost_benchmark.dart`

Cost of a full `Observer` rebuild (tracked build + dependency
re-registration) reading 1, 10, and 50 distinct `Observable<int>`
dependencies, 2,000 rebuilds each.

| Dependencies read | Result |
|---|---|
| 1 | not executed |
| 10 | not executed |
| 50 | not executed |

Expected shape: rebuild cost should scale roughly linearly with the
number of dependencies read, since each read does one
`TrackingContext._seen.add` (a `Set` insertion, O(1) amortized) plus one
`ListenerRegistry.add` (an O(n) `List.contains` scan over that
registry's own listeners — typically very small, often 1). The dominant
cost at low dependency counts is expected to be Flutter's own
`setState`/element rebuild machinery, not this package's tracking code.

## `observable_list_addall_benchmark.dart`

Confirms `ObservableList.addAll(1000)` notifies exactly once per call
(not once per element) over 500 runs, plus wall-clock time per call.

| Metric | Result |
|---|---|
| Notifications per run (expected: 1.0) | not executed |
| Time per `addAll(1000)` call | not executed |

This one also runs as a correctness check (`expect(totalNotifications,
kRuns)`), so if it's run and passes, the "notify once per bulk op"
guarantee (audit item 1) is confirmed on the current Dart/Flutter SDK in
use, not just by static reading of the source.
