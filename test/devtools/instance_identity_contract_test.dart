import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test('duplicate labels never become instance identity', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 32),
    );

    final Observable<int> first = Observable<int>(0, name: 'counter');
    final Observable<int> second = Observable<int>(0, name: 'counter');

    expect(first.objectId, isNot(second.objectId));
    first.value = 1;
    second.value = 2;
    first.close();
    second.close();

    final List<ObserverProtocolEvent> events = ObserverProtocol.events;
    final List<NodeCreatedEvent> creates = events
        .whereType<NodeCreatedEvent>()
        .toList();
    final List<NodeDisposedEvent> disposes = events
        .whereType<NodeDisposedEvent>()
        .toList();
    expect(creates.map((NodeCreatedEvent event) => event.objectId).toSet(), {
      first.objectId,
      second.objectId,
    });
    expect(disposes.map((NodeDisposedEvent event) => event.objectId).toSet(), {
      first.objectId,
      second.objectId,
    });
  });

  test('session and event identity are stable and ordered', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 10),
    );
    final String firstSession = ObserverProtocol.sessionId;
    final Observable<int> value = Observable<int>(0);
    value.value = 1;

    final List<ObserverProtocolEvent> events = ObserverProtocol.events;
    expect(events, isNotEmpty);
    expect(events.every((event) => event.protocolVersion == 1), isTrue);
    expect(events.every((event) => event.sessionId == firstSession), isTrue);
    expect(
      events.map((event) => event.eventId).toSet(),
      hasLength(events.length),
    );
    expect(
      events.map((event) => event.sequenceNumber),
      orderedEquals(
        List<int>.generate(events.length, (int index) => index + 1),
      ),
    );

    ObserverProtocol.startNewSession();
    expect(ObserverProtocol.sessionId, isNot(firstSession));
    expect(ObserverProtocol.events, isEmpty);
    expect(ObserverProtocol.snapshot().lastSequenceNumber, 0);
  });

  test('protocol stack traces remain opt-in', () {
    ObserverProtocol.configure(const ObserverProtocolConfig(enabled: true));
    Observable<int>(0);
    expect(ObserverProtocol.events.single.stackTrace, isNull);

    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, captureStackTraces: true),
    );
    Observable<int>(0);
    expect(ObserverProtocol.events.single.stackTrace, isNotNull);
  });
}
