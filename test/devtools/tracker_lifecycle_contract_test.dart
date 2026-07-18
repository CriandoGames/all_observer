import 'package:all_observer/all_observer.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test('computed lifecycle and recomputations share one stable identity', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, captureValues: true),
    );
    final Observable<int> source = Observable<int>(1, name: 'source');
    final Computed<int> doubled = Computed<int>(
      () => source.value * 2,
      name: 'doubled',
    );

    expect(doubled.value, 2);
    source.value = 2;
    expect(doubled.value, 4);
    doubled.close();

    final List<ObserverProtocolEvent> events = ObserverProtocol.events;
    expect(
      events.whereType<NodeCreatedEvent>().where(
        (event) => event.objectId == doubled.objectId,
      ),
      hasLength(1),
    );
    expect(
      events.whereType<NodeUpdatedEvent>().where(
        (event) => event.objectId == doubled.objectId,
      ),
      hasLength(1),
    );
    expect(
      events.whereType<NodeDisposedEvent>().where(
        (event) => event.objectId == doubled.objectId,
      ),
      hasLength(1),
    );
    expect(
      events.whereType<TrackerRunFinishedEvent>().where(
        (event) => event.trackerId == doubled.objectId,
      ),
      hasLength(2),
    );
  });

  testWidgets('Observer build has paired runs and disposes its node', (
    WidgetTester tester,
  ) async {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    final Observable<int> source = Observable<int>(0, name: 'widgetSource');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Observer(() => Text('${source.value}'), name: 'counterText'),
      ),
    );
    source.value = 1;
    await tester.pump();
    await tester.pumpWidget(const SizedBox.shrink());

    final NodeCreatedEvent observer = ObserverProtocol.events
        .whereType<NodeCreatedEvent>()
        .singleWhere((event) => event.kind == ObserverNodeKind.observer);
    final List<TrackerRunStartedEvent> starts = ObserverProtocol.events
        .whereType<TrackerRunStartedEvent>()
        .where((event) => event.trackerId == observer.objectId)
        .toList();
    final List<TrackerRunFinishedEvent> finishes = ObserverProtocol.events
        .whereType<TrackerRunFinishedEvent>()
        .where((event) => event.trackerId == observer.objectId)
        .toList();
    expect(starts, hasLength(2));
    expect(
      finishes.map((event) => event.runId),
      starts.map((event) => event.runId),
    );
    expect(
      ObserverProtocol.events.whereType<NodeDisposedEvent>().where(
        (event) => event.objectId == observer.objectId,
      ),
      hasLength(1),
    );
  });

  testWidgets('watch reports one complete conditional graph per build', (
    WidgetTester tester,
  ) async {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    final Observable<bool> enabled = Observable<bool>(true, name: 'enabled');
    final Observable<String> user = Observable<String>('Ada', name: 'user');

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (BuildContext context) {
            if (enabled.watch(context)) {
              return Text(user.watch(context));
            }
            return const Text('Disabled');
          },
        ),
      ),
    );
    await tester.pump();

    final ObserverNodeId watchId = ObserverProtocol.events
        .whereType<NodeCreatedEvent>()
        .singleWhere((event) => event.kind == ObserverNodeKind.watch)
        .objectId;
    final DependenciesChangedEvent initial = ObserverProtocol.events
        .whereType<DependenciesChangedEvent>()
        .singleWhere((event) => event.trackerId == watchId);
    expect(initial.currentDependencyIds, {enabled.objectId, user.objectId});

    enabled.value = false;
    await tester.pump();
    await tester.pump();

    final List<DependenciesChangedEvent> changes = ObserverProtocol.events
        .whereType<DependenciesChangedEvent>()
        .where((event) => event.trackerId == watchId)
        .toList();
    expect(changes, hasLength(2));
    expect(changes.last.currentDependencyIds, {enabled.objectId});
    expect(changes.last.removedDependencyIds, {user.objectId});
  });
}
