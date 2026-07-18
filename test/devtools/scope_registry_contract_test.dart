import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test('scope snapshot contains real registered resource identities', () {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    final Observable<int> source = Observable<int>(1);
    final ReactiveScope scope = ReactiveScope(name: 'controller');
    late final Computed<int> computed;
    late final Worker worker;

    scope.run(() {
      computed = Computed<int>(() => source.value * 2, name: 'scopedComputed');
      worker = ever(source, (_) {});
    });

    final ObserverScopeSnapshot scopeState =
        ObserverProtocol.snapshot().scopes.single;
    expect(scopeState.scopeId, scope.scopeId);
    expect(
      scopeState.resources.map((resource) => resource.resourceId).toSet(),
      {computed.objectId, worker.objectId},
    );

    scope.dispose();
    expect(ObserverProtocol.snapshot().scopes, isEmpty);
    final ProtocolScopeDisposedEvent disposed = ObserverProtocol.events
        .whereType<ProtocolScopeDisposedEvent>()
        .single;
    expect(disposed.registeredResourceCount, 2);
    expect(disposed.disposedResourceCount, 2);
    expect(disposed.failedDisposeCount, 0);
  });

  test('scope preserves disposer isolation and reports failed count', () {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    final ReactiveScope scope = ReactiveScope(name: 'failing');
    final List<Object> reports = <Object>[];
    final previousReporter = CoreErrorReporting.reporter;
    CoreErrorReporting.reporter =
        (
          Object error,
          StackTrace stackTrace, {
          required String library,
          required String context,
        }) {
          reports.add(error);
        };
    addTearDown(() => CoreErrorReporting.reporter = previousReporter);
    var successful = 0;
    scope.add(() => successful++);
    scope.add(() => throw StateError('dispose failed'));

    scope.dispose();

    expect(successful, 1);
    expect(reports, hasLength(1));
    final ProtocolScopeDisposedEvent event = ObserverProtocol.events
        .whereType<ProtocolScopeDisposedEvent>()
        .single;
    expect(event.registeredResourceCount, 2);
    expect(event.disposedResourceCount, 1);
    expect(event.failedDisposeCount, 1);
  });
}
