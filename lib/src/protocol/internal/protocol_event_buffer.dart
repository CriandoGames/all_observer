import 'dart:collection';

import '../events/observer_protocol_event.dart';

/// Bounded FIFO used by the protocol runtime.
///
/// FIFO limitado usado pelo runtime do protocolo.
final class ProtocolEventBuffer {
  /// Creates a buffer capped at [limit].
  ///
  /// Cria um buffer limitado por [limit].
  ProtocolEventBuffer(this.limit);

  /// Current event capacity.
  ///
  /// Capacidade atual de eventos.
  int limit;

  /// Number of events rejected or evicted since the last [clear].
  ///
  /// Eventos rejeitados ou removidos desde o último [clear].
  int droppedCount = 0;
  final Queue<ObserverProtocolEvent> _events = Queue<ObserverProtocolEvent>();

  /// Immutable retained events, oldest first.
  ///
  /// Eventos retidos imutáveis, do mais antigo ao mais recente.
  List<ObserverProtocolEvent> get events =>
      List<ObserverProtocolEvent>.unmodifiable(_events);

  /// Oldest retained sequence, or `null` when empty.
  ///
  /// Sequência retida mais antiga, ou `null` quando vazio.
  int? get firstAvailableSequence =>
      _events.isEmpty ? null : _events.first.sequenceNumber;

  /// Newest retained sequence, or `null` when empty.
  ///
  /// Sequência retida mais recente, ou `null` quando vazio.
  int? get lastAvailableSequence =>
      _events.isEmpty ? null : _events.last.sequenceNumber;

  /// Appends [event], evicting the oldest item when full.
  ///
  /// Adiciona [event], removendo o item mais antigo quando cheio.
  void add(ObserverProtocolEvent event) {
    if (limit == 0) {
      droppedCount++;
      return;
    }
    if (_events.length == limit) {
      _events.removeFirst();
      droppedCount++;
    }
    _events.addLast(event);
  }

  /// Removes retained events and resets [droppedCount].
  ///
  /// Remove eventos retidos e zera [droppedCount].
  void clear() {
    _events.clear();
    droppedCount = 0;
  }
}
