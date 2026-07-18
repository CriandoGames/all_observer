import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ProtocolRecorder extends ObserverProtocolInspector {
  final List<ObserverProtocolEvent> events = <ObserverProtocolEvent>[];

  @override
  void onProtocolEvent(ObserverProtocolEvent event) => events.add(event);
}

final class _ThrowingProtocolInspector extends ObserverProtocolInspector {
  @override
  void onProtocolEvent(ObserverProtocolEvent event) => throw StateError('boom');
}

final class _LegacyInspector implements ObserverInspector {
  int updates = 0;

  @override
  void onCreate(ObservableCreateEvent event) {}
  @override
  void onDispose(ObservableDisposeEvent event) {}
  @override
  void onEffectRun(EffectEvent event) {}
  @override
  void onScopeDispose(ScopeDisposeEvent event) {}
  @override
  void onTrack(TrackEvent event) {}
  @override
  void onUpdate(ObservableUpdateEvent event) => updates++;
  @override
  void onWarning(WarningEvent event) {}
}

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test('protocol uses the existing ObserverInspector registration layer', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, captureValues: true),
    );
    final _ProtocolRecorder protocol = _ProtocolRecorder();
    final _LegacyInspector legacy = _LegacyInspector();
    ObserverConfig.inspectors.addAll(<ObserverInspector>[protocol, legacy]);

    final Observable<int> value = Observable<int>(0);
    value.value = 1;

    expect(protocol.events.whereType<NodeUpdatedEvent>(), hasLength(1));
    expect(legacy.updates, 1);
  });

  test('throwing protocol inspector is isolated from state and peers', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, captureValues: true),
    );
    final _ProtocolRecorder recorder = _ProtocolRecorder();
    final List<Object> reportedErrors = <Object>[];
    final previousReporter = CoreErrorReporting.reporter;
    CoreErrorReporting.reporter =
        (
          Object error,
          StackTrace stackTrace, {
          required String library,
          required String context,
        }) {
          reportedErrors.add(error);
        };
    addTearDown(() => CoreErrorReporting.reporter = previousReporter);
    ObserverConfig.inspectors.addAll(<ObserverInspector>[
      _ThrowingProtocolInspector(),
      recorder,
    ]);

    final Observable<int> value = Observable<int>(0);
    expect(() => value.value = 1, returnsNormally);
    expect(value.value, 1);
    expect(recorder.events.whereType<NodeUpdatedEvent>(), hasLength(1));
    expect(ObserverProtocol.snapshot().nodes.single.valueSummary?.display, '1');
    expect(reportedErrors, isNotEmpty);
  });

  test('disabled protocol retains no events or registry state', () {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: false));
    final Observable<int> value = Observable<int>(0);
    value.value = 1;
    value.close();

    expect(ObserverProtocol.events, isEmpty);
    expect(ObserverProtocol.snapshot().nodes, isEmpty);
    expect(ObserverProtocol.lastSequenceNumber, 0);
  });

  test(
    'registry can be disabled while the bounded event stream stays active',
    () {
      ObserverProtocol.configure(
        const ObserverProtocolConfig(
          enabled: true,
          registryEnabled: false,
          eventBufferSize: 16,
        ),
      );
      final Observable<int> source = Observable<int>(0);
      final void Function() dispose = effect(() => source.value);

      final ObserverProtocolSnapshot snapshot = ObserverProtocol.snapshot();
      expect(snapshot.nodes, isEmpty);
      expect(snapshot.dependencies, isEmpty);
      expect(snapshot.scopes, isEmpty);
      expect(
        ObserverProtocol.events.whereType<TrackerRunFinishedEvent>(),
        hasLength(1),
      );
      expect(
        ObserverProtocol.events.whereType<DependenciesChangedEvent>(),
        isEmpty,
      );
      dispose();
    },
  );
}
