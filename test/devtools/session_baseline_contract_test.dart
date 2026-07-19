import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test('late activation explicitly marks an incomplete baseline', () {
    final _LiveGraph graph = _LiveGraph.create();

    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 200),
    );
    graph.exercise();
    graph.dispose();

    _expectIncompleteBaseline(
      ObserverProtocol.snapshot(),
      ObserverProtocolBaselineStatus.activatedAfterObjectsWereAllocated,
    );
  });

  test('new session with live nodes marks an incomplete baseline', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 200),
    );
    final _LiveGraph graph = _LiveGraph.create();

    ObserverProtocol.startNewSession();
    graph.exercise();
    graph.dispose();

    _expectIncompleteBaseline(
      ObserverProtocol.snapshot(),
      ObserverProtocolBaselineStatus.restartedWithActiveObjects,
    );
  });

  test('reconfigure with live nodes marks an incomplete baseline', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 200),
    );
    final _LiveGraph graph = _LiveGraph.create();

    ObserverProtocol.configure(
      const ObserverProtocolConfig(
        enabled: true,
        captureValues: true,
        eventBufferSize: 200,
      ),
    );
    graph.exercise();
    graph.dispose();

    _expectIncompleteBaseline(
      ObserverProtocol.snapshot(),
      ObserverProtocolBaselineStatus.reconfiguredWithActiveObjects,
    );
  });
}

void _expectIncompleteBaseline(
  ObserverProtocolSnapshot snapshot,
  ObserverProtocolBaselineStatus expectedStatus,
) {
  final Set<ObserverNodeId> registered = snapshot.nodes
      .map((ObserverNodeSnapshot node) => node.objectId)
      .toSet();
  final Set<ObserverNodeId> referenced = <ObserverNodeId>{};

  for (final ObserverProtocolEvent event in ObserverProtocol.events) {
    switch (event) {
      case NodeUpdatedEvent(:final objectId):
      case NodeDisposedEvent(:final objectId):
        referenced.add(objectId);
      case TrackerRunStartedEvent(:final trackerId):
      case TrackerRunFinishedEvent(:final trackerId):
        referenced.add(trackerId);
      case DependenciesChangedEvent(
        :final trackerId,
        :final currentDependencyIds,
      ):
        referenced
          ..add(trackerId)
          ..addAll(currentDependencyIds);
      case ScopeResourceRegisteredEvent(:final scopeId, :final resourceId):
        referenced
          ..add(scopeId)
          ..add(resourceId);
      case ProtocolScopeDisposedEvent(:final scopeId):
        referenced.add(scopeId);
      default:
        break;
    }
  }

  expect(referenced.difference(registered), isNotEmpty);
  expect(snapshot.isBaselineComplete, isFalse);
  expect(snapshot.baselineStatus, expectedStatus);
}

final class _LiveGraph {
  _LiveGraph._({
    required this.source,
    required this.computed,
    required this.disposeEffect,
    required this.worker,
    required this.scope,
  });

  factory _LiveGraph.create() {
    final Observable<int> source = Observable<int>(1, name: 'sessionSource');
    final Computed<int> computed = Computed<int>(
      () => source.value * 2,
      name: 'sessionComputed',
    );
    computed.value;
    final void Function() disposeEffect = effect(
      () => source.value,
      name: 'sessionEffect',
    );
    final Worker worker = ever<int>(source, (_) {});
    final ReactiveScope scope = ReactiveScope(name: 'sessionScope')
      ..add(worker.dispose);
    return _LiveGraph._(
      source: source,
      computed: computed,
      disposeEffect: disposeEffect,
      worker: worker,
      scope: scope,
    );
  }

  final Observable<int> source;
  final Computed<int> computed;
  final void Function() disposeEffect;
  final Worker worker;
  final ReactiveScope scope;

  void exercise() {
    source.value = 2;
    computed.value;
  }

  void dispose() {
    disposeEffect();
    scope.dispose();
    computed.close();
    source.close();
  }
}
