import 'dart:typed_data';

import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ThrowingString {
  @override
  String toString() => throw StateError('must not escape');
}

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test('arbitrary values never require toString or deep serialization', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, captureValues: true),
    );

    expect(() => Observable<Object>(_ThrowingString()), returnsNormally);
    final List<Object> circularValue = <Object>[];
    circularValue.add(circularValue);
    Observable<Object>(circularValue);
    Observable<Uint8List>(Uint8List(10000));

    final List<ObserverNodeSnapshot> nodes = ObserverProtocol.snapshot().nodes;
    expect(nodes, hasLength(3));
    expect(nodes.first.valueSummary?.display, isNull);
    expect(nodes[1].valueSummary?.display, contains('length: 1'));
    expect(nodes[2].valueSummary?.display, contains('length: 10000'));
  });

  test('strings are truncated and sensitive-looking content is redacted', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(
        enabled: true,
        captureValues: true,
        maxStringLength: 16,
      ),
    );
    Observable<String>('abcdefghijklmnopqrstuvwxyz', name: 'long');
    Observable<String>('password=secret-value', name: 'credential');

    final List<ObserverValueSummary?> summaries = ObserverProtocol.snapshot()
        .nodes
        .map((node) => node.valueSummary)
        .toList();
    expect(summaries.first?.isTruncated, isTrue);
    expect(summaries.first?.display, 'abcdefghijklmnop');
    expect(summaries.last?.isRedacted, isTrue);
    expect(summaries.last?.display, isNull);
  });

  test('application can explicitly redact a value', () {
    ObserverProtocol.configure(
      ObserverProtocolConfig(
        enabled: true,
        captureValues: true,
        redactValue: (Object? value) => value == 42,
      ),
    );
    Observable<int>(42, name: 'privateNumber');

    final ObserverValueSummary? summary =
        ObserverProtocol.snapshot().nodes.single.valueSummary;
    expect(summary?.isRedacted, isTrue);
    expect(summary?.display, isNull);
  });

  test('ring buffer supports zero and reports dropped events', () {
    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
    );
    Observable<int>(0);
    expect(ObserverProtocol.events, isEmpty);
    expect(ObserverProtocol.droppedEventCount, greaterThan(0));

    ObserverProtocol.configure(
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 1),
    );
    final Observable<int> value = Observable<int>(0);
    value.value = 1;
    expect(ObserverProtocol.events, hasLength(1));
    expect(ObserverProtocol.droppedEventCount, greaterThan(0));
    final ObserverProtocolSnapshot snapshot = ObserverProtocol.snapshot();
    expect(
      snapshot.firstAvailableSequence,
      ObserverProtocol.events.single.sequenceNumber,
    );
    expect(
      snapshot.lastAvailableSequence,
      ObserverProtocol.events.single.sequenceNumber,
    );
  });

  for (final int size in <int>[10, 1000]) {
    test('ring buffer remains bounded at $size events', () {
      ObserverProtocol.configure(
        ObserverProtocolConfig(enabled: true, eventBufferSize: size),
      );
      final Observable<int> value = Observable<int>(0);
      for (int next = 1; next <= size + 5; next++) {
        value.value = next;
      }

      expect(ObserverProtocol.events, hasLength(size));
      expect(ObserverProtocol.droppedEventCount, 6);
      expect(
        ObserverProtocol.events.first.sequenceNumber,
        ObserverProtocol.lastSequenceNumber - size + 1,
      );
    });
  }
}
