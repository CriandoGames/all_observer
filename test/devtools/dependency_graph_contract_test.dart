import 'package:all_observer/all_observer.dart';
import 'package:all_observer/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test(
    'conditional effect reports added, retained and removed dependencies',
    () {
      ObserverProtocol.configure(
        const ObserverProtocolConfig(enabled: true, eventBufferSize: 100),
      );
      final Observable<bool> enabled = Observable<bool>(true, name: 'enabled');
      final Observable<String> user = Observable<String>('Ada', name: 'user');

      final Disposer dispose = effect(() {
        enabled.value;
        if (enabled.value) {
          user.value;
        }
      }, name: 'conditional');

      final DependenciesChangedEvent initial = ObserverProtocol.events
          .whereType<DependenciesChangedEvent>()
          .single;
      expect(initial.currentDependencyIds, {enabled.objectId, user.objectId});
      expect(initial.addedDependencyIds, {enabled.objectId, user.objectId});
      expect(initial.removedDependencyIds, isEmpty);

      enabled.value = false;
      final List<DependenciesChangedEvent> changes = ObserverProtocol.events
          .whereType<DependenciesChangedEvent>()
          .toList();
      expect(changes, hasLength(2));
      expect(changes.last.currentDependencyIds, {enabled.objectId});
      expect(changes.last.addedDependencyIds, isEmpty);
      expect(changes.last.removedDependencyIds, {user.objectId});

      final ObserverProtocolSnapshot snapshot = ObserverProtocol.snapshot();
      expect(snapshot.dependencies.single.dependencyIds, {enabled.objectId});
      dispose();
    },
  );

  test('tracker finish is emitted on error and original error propagates', () {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    final Observable<int> source = Observable<int>(0);

    expect(
      () => effect(() {
        source.value;
        throw StateError('original');
      }, name: 'throwing'),
      throwsA(
        isA<StateError>().having(
          (error) => error.message,
          'message',
          'original',
        ),
      ),
    );

    expect(
      ObserverProtocol.events.whereType<TrackerRunStartedEvent>(),
      hasLength(1),
    );
    final TrackerRunFinishedEvent finished = ObserverProtocol.events
        .whereType<TrackerRunFinishedEvent>()
        .single;
    expect(finished.completedWithError, isTrue);
    expect(finished.dependencyIds, {source.objectId});
  });

  test('snapshot supports a consumer registered after node creation', () {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    final Observable<int> value = Observable<int>(1, name: 'late');
    final ObserverProtocolSnapshot beforeConsumer = ObserverProtocol.snapshot();
    expect(beforeConsumer.nodes.single.objectId, value.objectId);

    final _LateRecorder recorder = _LateRecorder();
    ObserverConfig.inspectors.add(recorder);
    value.value = 2;

    expect(recorder.events.whereType<NodeUpdatedEvent>(), hasLength(1));
    expect(
      recorder.events.single.sequenceNumber,
      greaterThan(beforeConsumer.lastSequenceNumber),
    );
  });
}

final class _LateRecorder extends ObserverProtocolInspector {
  final List<ObserverProtocolEvent> events = <ObserverProtocolEvent>[];

  @override
  void onProtocolEvent(ObserverProtocolEvent event) => events.add(event);
}
