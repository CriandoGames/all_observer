import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  final Map<
    ObserverProtocolInternalErrorCategory,
    bool Function(ObserverProtocolEvent)
  >
  cases =
      <
        ObserverProtocolInternalErrorCategory,
        bool Function(ObserverProtocolEvent)
      >{
        ObserverProtocolInternalErrorCategory.creation: (event) =>
            event is NodeCreatedEvent,
        ObserverProtocolInternalErrorCategory.update: (event) =>
            event is NodeUpdatedEvent,
        ObserverProtocolInternalErrorCategory.dependencyDelta: (event) =>
            event is DependenciesChangedEvent,
        ObserverProtocolInternalErrorCategory.warning: (event) =>
            event is WarningRaisedEvent,
        ObserverProtocolInternalErrorCategory.dispose: (event) =>
            event is NodeDisposedEvent,
        ObserverProtocolInternalErrorCategory.scope: (event) =>
            event is ScopeCreatedEvent,
        ObserverProtocolInternalErrorCategory.trackerFinished: (event) =>
            event is TrackerRunFinishedEvent,
      };

  for (final MapEntry<
        ObserverProtocolInternalErrorCategory,
        bool Function(ObserverProtocolEvent)
      >
      entry
      in cases.entries) {
    test('inspector failure is counted and isolated for ${entry.key.name}', () {
      ObserverProtocol.configure(
        const ObserverProtocolConfig(enabled: true, eventBufferSize: 100),
      );
      final previousReporter = CoreErrorReporting.reporter;
      CoreErrorReporting.reporter =
          (
            Object error,
            StackTrace stackTrace, {
            required String library,
            required String context,
          }) {};
      addTearDown(() => CoreErrorReporting.reporter = previousReporter);
      final _ThrowOn matching = _ThrowOn(entry.value);
      final _Recorder peer = _Recorder();
      ObserverConfig.inspectors.addAll(<ObserverInspector>[matching, peer]);

      _emitEveryCategory();

      final ObserverProtocolSnapshot snapshot = ObserverProtocol.snapshot();
      expect(snapshot.protocolInternalErrorCount, 1);
      expect(snapshot.protocolInternalErrorCounts[entry.key], 1);
      expect(
        snapshot.lastProtocolInternalErrorCode,
        'inspector_dispatch_failed',
      );
      expect(
        snapshot.lastProtocolInternalErrorCode,
        isNot(contains('synthetic-secret')),
      );
      expect(peer.events.any(entry.value), isTrue);
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.dependencies, isEmpty);
      expect(snapshot.scopes, isEmpty);
    });
  }

  test('internal failure reporting is protected against recursion', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 100),
    );
    ObserverConfig.inspectors.add(_AlwaysThrow());
    final previousReporter = CoreErrorReporting.reporter;
    var reporterCalls = 0;
    CoreErrorReporting.reporter =
        (
          Object error,
          StackTrace stackTrace, {
          required String library,
          required String context,
        }) {
          reporterCalls++;
          if (reporterCalls == 1) {
            ObserverProtocol.warningRaised(
              warningCode: 'reporter_reentry',
              message: 'synthetic reporter reentry',
            );
          }
        };
    addTearDown(() => CoreErrorReporting.reporter = previousReporter);

    Observable<int>(0);

    expect(reporterCalls, 1);
    expect(ObserverProtocol.snapshot().protocolInternalErrorCount, 1);
  });
}

void _emitEveryCategory() {
  final Observable<int> updated = Observable<int>(0, name: 'updated');
  updated.value = 1;
  final void Function() disposeEffect = effect(
    () => updated.value,
    name: 'tracked',
  );
  ObserverProtocol.warningRaised(
    warningCode: 'synthetic_warning',
    message: 'synthetic warning',
  );
  final ReactiveScope scope = ReactiveScope(name: 'scope');
  scope.dispose();
  disposeEffect();
  updated.close();
}

final class _ThrowOn extends ObserverProtocolInspector {
  _ThrowOn(this.matches);

  final bool Function(ObserverProtocolEvent) matches;
  bool _hasThrown = false;

  @override
  void onProtocolEvent(ObserverProtocolEvent event) {
    if (!_hasThrown && matches(event)) {
      _hasThrown = true;
      throw StateError('synthetic-secret must not be retained');
    }
  }
}

final class _Recorder extends ObserverProtocolInspector {
  final List<ObserverProtocolEvent> events = <ObserverProtocolEvent>[];

  @override
  void onProtocolEvent(ObserverProtocolEvent event) => events.add(event);
}

final class _AlwaysThrow extends ObserverProtocolInspector {
  @override
  void onProtocolEvent(ObserverProtocolEvent event) {
    throw StateError('synthetic recursive inspector failure');
  }
}
