# Observer Protocol v1

Observer Protocol is the versioned observability contract between the
`all_observer` reactive core and external diagnostic consumers. It does not
depend on Flutter DevTools, navigation, VM Service, networking, or state
editing.

## Enable and consume

The protocol is disabled by default. Protocol consumers use the existing
`ObserverInspector` registration layer:

```dart
final class AuditInspector extends ObserverProtocolInspector {
  @override
  void onProtocolEvent(ObserverProtocolEvent event) {
    // Export, inspect or assert the immutable event.
  }
}

void configureDiagnostics() {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(
      enabled: true,
      eventBufferSize: 1000,
    ),
  );
  ObserverConfig.inspectors.add(AuditInspector());
}
```

`ObserverProtocolInspector` extends `ObserverInspector`; there is no second
consumer list. Existing classes that extend or implement `ObserverInspector`
do not receive a new required method and continue to compile unchanged.

## Identity and ordering

- `observerProtocolVersion` starts at `1` and is independent from the package
  version.
- `sessionId` changes whenever `configure` or `startNewSession` starts an
  isolated session.
- `eventId` is unique inside the session.
- `sequenceNumber` is strictly increasing and is the ordering source of
  truth. Timestamp equality does not affect ordering.
- `timestampMicros` is wall-clock time from `DateTime.now()`, expressed as
  microseconds since Unix epoch.
- `ObserverNodeId` comes from a process-local monotonic counter. Labels,
  public `hashCode`, values, and timestamps are never identity.

`Observable`, `Computed`, `ReactiveScope`, and `Worker` expose their stable
protocol identity. `Observer`, `watch(context)`, and effects use the same ID
internally throughout their lifecycle.

## Events

Node lifecycle:

- `NodeCreatedEvent`
- `NodeUpdatedEvent`
- `NodeDisposedEvent`

Tracked execution and graph changes:

- `TrackerRunStartedEvent`
- `DependenciesChangedEvent`
- `TrackerRunFinishedEvent`

Scope ownership:

- `ScopeCreatedEvent`
- `ScopeResourceRegisteredEvent`
- `ProtocolScopeDisposedEvent`

Diagnostics:

- `WarningRaisedEvent`

Tracker finish is emitted from a `finally` path. If the tracked callback
throws, `completedWithError` is true and the original exception still follows
the existing propagation/reporting behavior.

`DependenciesChangedEvent` contains the complete final set plus explicit
added and removed sets. Repeated reads are deduplicated. If a conditional
branch stops reading a node, its ID appears in `removedDependencyIds`.

## Registry and snapshot

`ObserverProtocol.snapshot()` returns immutable metadata for:

- active nodes;
- active tracker dependencies;
- active scopes and their registered resources;
- the last represented sequence;
- dropped-event and available-buffer boundaries.

The registry stores IDs, kinds, labels, type names, timestamps, and safe value
summaries. It does not retain user objects or raw arbitrary values. Disposed
nodes/scopes and their dependency edges are removed. A consumer registered
after node creation can request a snapshot and then apply events whose
`sequenceNumber` is greater than `snapshot.lastSequenceNumber`.

Starting a new session clears registry and buffer state. Objects that predate
a newly started session are not rediscovered automatically until a future
protocol version defines an explicit re-registration contract.

Consumers must inspect `snapshot.baselineStatus` (or
`snapshot.isBaselineComplete`) before reconciling events. Late activation,
reconfiguration with active objects, and restarting with active objects are
reported explicitly as incomplete baselines. This is conservative by design:
the disabled path does not retain a strong active-object registry.

Protocol v1 also reports `instrumentationCoverage: partial` with the
`reactiveCollections` limitation. A DevTools consumer must not present the
graph as complete while that limitation is present.

## Event buffer and dropped events

The event buffer is bounded and removes the oldest event when full.
`droppedEventCount` counts evicted events. A size of zero dispatches events to
attached protocol inspectors but retains none; every event increments the
dropped count. Snapshot fields `firstAvailableSequence` and
`lastAvailableSequence` describe the retained window.

## Value safety

Raw values are never stored in events or snapshots. With `captureValues:
false`, summaries contain only the runtime type. With capture enabled:

- `null`, booleans, numbers, enums, and bounded strings may have display
  text;
- sensitive-looking strings are redacted;
- long strings are truncated at `maxStringLength`;
- lists, maps, sets, and `Uint8List` expose only type and length;
- arbitrary objects are never passed to `toString()` and are never traversed.

Applications can provide `redactValue` in `ObserverProtocolConfig` to force
redaction using their own policy. If that callback throws, the protocol fails
closed and redacts the value without interrupting the reactive update.

This makes summaries safe for circular objects and for objects with slow,
throwing, or extremely large `toString()` implementations. Stack traces are
independently opt-in and disabled by default.

`ObserverProtocolConfig.productionSafe()` disables value and stack capture
and replaces user-provided node/scope labels with `[redacted]`. The normal
constructor keeps its historical label behavior; applications can opt into
label protection alone with `redactLabels: true`. String truncation counts
Unicode scalar values and never splits a surrogate pair.

## Internal failure status

Inspector exceptions remain isolated from application updates and later
inspectors. Snapshots expose `protocolInternalErrorCount`, categorized counts,
and `lastProtocolInternalErrorCode`. The last code is fixed and sanitized; an
exception message is never retained. Accounting is non-emitting to prevent
recursive diagnostic failures.

## Overhead model

When disabled, event construction, value summarization, registry mutation,
stack capture, and buffer writes return early. Nodes still receive a cheap
monotonic identity so their public `objectId` remains stable regardless of
when diagnostics are enabled. Enabling the protocol pays only for configured
registry/buffer/value/stack features.

## Limits

This protocol is not a leak detector. Missing `dispose()` is not, by itself,
proof of a leak. Version 1 has no routes/screens, Flutter DevTools UI, VM
Service transport, networking, remote actions, raw-value editing, or automatic
correlation with widgets outside instrumented trackers.

`ObservableList`, `ObservableMap`, and `ObservableSet` still use legacy
inspection in version 1 and do not appear as independent protocol nodes.
Starting a new session also does not automatically rediscover objects that
were created in an earlier session.
