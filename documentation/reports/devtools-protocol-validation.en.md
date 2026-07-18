# Phase 1 validation — Observer Protocol

Portuguese version: [devtools-protocol-validation.md](devtools-protocol-validation.md)

## Decision

**READY WITH RESTRICTIONS.** Protocol v1 can support external consumers for
scalar observables, computed values, Observer, `watch`, effects, scopes, and
workers without depending on Flutter DevTools. The real restrictions are
listed below: reactive collections still have legacy-only instrumentation,
and objects predating a new session are not automatically rediscovered.

## Pre-implementation analysis

The legacy flow remains intact:

| Legacy event | Main creation/dispatch path |
| --- | --- |
| `ObservableCreateEvent` | `CoreObservable` calls `dispatchToInspectors`; its wrapper uses `ObserverLogger` only for console output |
| `ObservableUpdateEvent` | `CoreObservable` after an actual change; wrappers avoid duplicate dispatch |
| `ObservableDisposeEvent` | `CoreObservable`/`CoreComputed`; wrappers keep console logging only |
| `TrackEvent` | `DependencyTracker.reportRead`, on the first distinct read in a run |
| `WarningEvent` | `CoreObservable`, `ReactiveScope`, and `ObserverLogger.warn` |
| `EffectEvent` | `effect`, after successful execution |
| `ScopeDisposeEvent` | `ReactiveScope.dispose` |

`ObserverLogger` remains responsible for console output and dispatches only
when requested. `RecordingInspector` still caps its list with `removeAt(0)`
after `maxEvents`. Trackers still use the `DependencyTracker` stack; listener
registrations are replaced on every run, removing stale dependencies.
`ReactiveScope` keeps LIFO disposal and failure isolation.

The implemented plan separated models, events, snapshots, and internal
runtime; preserved existing events/classes; added disabled-path early returns;
and covered identity, lifecycle, graph changes, scopes, values, buffering,
late consumers, isolation, and compatibility. The main risks were breaking
`implements ObserverInspector`, duplicate dispatch, retaining user values, and
changing exception propagation.

## Architecture and APIs

```text
reactive core -> Observer Protocol -> ObserverConfig.inspectors
                                      -> opt-in consumers
```

`ObserverProtocolInspector extends ObserverInspector` is the opt-in
capability. There is no second inspector list. `ObserverProtocol`,
`ObserverProtocolConfig`, events, IDs, summaries, and snapshots are exported
by `all_observer.dart` and `core.dart`.

New files are split into focused contexts:

- `lib/src/protocol/model`: identity, kind, and value summary;
- `lib/src/protocol/events`: envelope and domain events;
- `lib/src/protocol/snapshot`: immutable public state;
- `lib/src/protocol/internal`: session, registry, buffer, and runtimes;
- `test/devtools`: contract tests;
- `benchmark`: reproducible harness;
- `documentation/en`, `documentation/pt-BR`, and `documentation/reports`: use,
  validation, and measurements.

Modified existing files include public barrels, configuration/logging,
`CoreObservable`, `CoreComputed`, `DependencyTracker`, `ReactiveScope`,
`Observable`, `Computed`, effect, Observer, `watch`, workers, READMEs, and
architecture. Reactive semantics and legacy events are preserved.

## Protocol contract

- `protocolVersion`: package-independent constant, currently `1`;
- `sessionId`: initialization identity; changes on `configure` and
  `startNewSession`;
- `eventId`: unique within a session;
- `sequenceNumber`: strictly increasing within a session;
- `timestampMicros`: wall clock from `DateTime.now()`;
- `objectId`/`scopeId`/`trackerId`: stable monotonic `ObserverNodeId`, unrelated
  to labels or public `hashCode`;
- `runId`: unique tracked-run identity;
- `nodeKind`: observable, computed, observer, watch, effect, scope, worker, or
  subscription.

Representative event:

```dart
NodeUpdatedEvent(
  protocolVersion: 1,
  sessionId: sessionId,
  eventId: 'event-2',
  sequenceNumber: 2,
  timestampMicros: timestamp,
  objectId: counter.objectId,
  kind: ObserverNodeKind.observable,
  oldValueSummary: oldSummary,
  newValueSummary: newSummary,
)
```

Lifecycle uses `NodeCreatedEvent`, `NodeUpdatedEvent`, and
`NodeDisposedEvent`. Runs use `TrackerRunStartedEvent`,
`DependenciesChangedEvent`, and `TrackerRunFinishedEvent`. Scopes use
`ScopeCreatedEvent`, `ScopeResourceRegisteredEvent`, and
`ProtocolScopeDisposedEvent`. Diagnostics use `WarningRaisedEvent`. The scope
dispose name avoids collision with its legacy counterpart.

Tracker finish is emitted from `finally`, includes monotonic duration, final
dependencies, and `completedWithError`, and never replaces the original
exception.

## Compatibility

Strategy A, additive dispatch, was selected: the core preserves the legacy
event and emits v1 separately. Adapting a legacy event would lose identity and
graph data; a bridge could not precisely observe scopes and removed edges.
Additive dispatch costs work only when enabled, has the lowest regression
risk, and leaves any future legacy removal explicit.

| Change | `extends` | `implements` | Breaking | Strategy |
| --- | ---: | ---: | ---: | --- |
| No new `ObserverInspector` method | preserved | preserved | no | legacy class untouched |
| v1 consumer | opt-in | opt-in | no | `ObserverProtocolInspector` |
| Registration | unchanged | unchanged | no | `ObserverConfig.inspectors` |
| Legacy events | unchanged | unchanged | no | dispatch retained |

Each v1 consumer is called in isolation from a copy of the list. An exception
is forwarded to `CoreErrorReporting` and does not interrupt later consumers,
registry updates, or reactive updates.

## Registry, snapshot, and buffer

The registry retains immutable metadata only: IDs, kinds, labels, type names,
timestamps, safe summaries, current edges, and scope resource IDs/kinds. It
stores neither raw values nor user-object references. Disposal removes the
node and related edges. Private tracker-disposal state uses `Expando<bool>`;
the tracker exposes no public `isDisposed` member.

`ObserverProtocol.snapshot()` copies active nodes, dependencies, and scopes
into immutable collections. `lastSequenceNumber` lets a consumer apply only
events after the snapshot. A consumer may register after object creation in
the same session.

The ring buffer evicts the oldest event at capacity. Size zero retains no
events, still dispatches, and counts every event as dropped. The snapshot
reports `droppedEventCount`, `firstAvailableSequence`, and
`lastAvailableSequence`.

## Dependency graph

At the end of each run, the deduplicated final set atomically replaces the
previous one. For `enabled ? user : fallback`, for example:

```text
run 1: current={enabled,user}, added={enabled,user}, removed={}
run 2: current={enabled},      added={},             removed={user}
```

A retained dependency remains in `current` but not in `added` or `removed`.
`DependenciesChangedEvent` is emitted only when the set changes.

## Value safety

Without value capture, only type metadata is retained. With capture enabled,
null/bool/numbers/enums and bounded strings may display content;
List/Map/Set/`Uint8List` display type and length only. Suspicious strings are
redacted and long strings are truncated. `redactValue` supplies an explicit
application policy and fails closed. Arbitrary objects are neither traversed
nor passed to `toString()`, so slow, huge, circular, or throwing
implementations cannot interrupt an update.

## Tests and benchmark

The 21 cases under `test/devtools` cover:

| File | Gap proved closed |
| --- | --- |
| `instance_identity_contract_test.dart` | duplicate labels, session, IDs, sequence, and opt-in stacks |
| `inspector_dispatch_contract_test.dart` | single registration layer, legacy `implements`, isolation, disabled mode, registry opt-out |
| `dependency_graph_contract_test.dart` | added/retained/removed edges, tracker errors, late snapshots |
| `tracker_lifecycle_contract_test.dart` | computed lifecycle/recompute, paired Observer runs, and one complete conditional `watch` graph per build |
| `scope_registry_contract_test.dart` | resource identity and failed-disposer counts |
| `value_safety_contract_test.dart` | hostile/circular `toString`, large collections, bytes, strings, redaction, buffers 0/1/10/1000 |

Final verification reports no `dart analyze` issues, 21 passing contract cases,
and a passing complete Flutter suite. Reproducible measurements are in
[observer-protocol-benchmark.en.md](observer-protocol-benchmark.en.md); in this
sample an update changed from 0.0357 to 0.4384 µs/op when enabled without a
consumer.

## Remaining limitations

- `ObservableList`, `ObservableMap`, and `ObservableSet` remain on the legacy
  path and do not yet appear as independent v1 nodes.
- Starting another session does not rediscover existing objects; initialize
  the protocol before creating them.
- There is no route, Flutter DevTools, VM Service, network, or UI integration.
- There is no state editing, remote action, or automatic leak detection.
- Missing disposal is incomplete evidence, not proof of a leak.
- The `Stopwatch` harness does not measure allocations.

The recommended next phase is to validate an external transport/consumer and
explicitly decide the collection contract before building any UI. It was not
implemented in this delivery.
