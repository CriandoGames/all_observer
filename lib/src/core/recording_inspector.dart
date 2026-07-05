import 'observer_inspector.dart';

/// An [ObserverInspector] that records every event it receives in memory,
/// bounded by [maxEvents]. Useful as a lightweight audit trail, and for
/// asserting exactly which notifications fired in a test — without the
/// hardcoded console logging noise.
///
/// ```dart
/// final recorder = RecordingInspector();
/// ObserverConfig.inspectors.add(recorder);
///
/// count.value = 1;
///
/// expect(recorder.events.whereType<ObservableUpdateEvent>(), hasLength(1));
/// ```
///
/// Um [ObserverInspector] que registra em memória todo evento que recebe,
/// limitado por [maxEvents]. Útil como uma trilha de auditoria leve, e para
/// afirmar exatamente quais notificações dispararam em um teste — sem o
/// ruído do logging fixo no console.
class RecordingInspector implements ObserverInspector {
  /// Creates a [RecordingInspector] that keeps at most [maxEvents] events,
  /// discarding the oldest once the limit is reached (a ring buffer, not an
  /// unbounded log — long-running apps should not leak memory just for
  /// having this attached). Default: `1000`.
  ///
  /// Cria um [RecordingInspector] que mantém no máximo [maxEvents] eventos,
  /// descartando o mais antigo ao atingir o limite (um buffer circular, não
  /// um log ilimitado — apps de longa duração não devem vazar memória só
  /// por ter isto anexado). Padrão: `1000`.
  RecordingInspector({this.maxEvents = 1000})
    : assert(maxEvents > 0, 'maxEvents must be positive');

  /// Maximum number of events retained. Oldest events are dropped first.
  ///
  /// Número máximo de eventos retidos. Os mais antigos são descartados
  /// primeiro.
  final int maxEvents;

  final List<ObservableEvent> _events = <ObservableEvent>[];

  /// Every event recorded so far, oldest first, capped at [maxEvents].
  ///
  /// Todo evento registrado até agora, do mais antigo ao mais recente,
  /// limitado a [maxEvents].
  List<ObservableEvent> get events =>
      List<ObservableEvent>.unmodifiable(_events);

  /// Removes every recorded event. Does not change [maxEvents].
  ///
  /// Remove todo evento registrado. Não altera [maxEvents].
  void clear() => _events.clear();

  void _record(ObservableEvent event) {
    _events.add(event);
    if (_events.length > maxEvents) {
      _events.removeAt(0);
    }
  }

  @override
  void onCreate(ObservableCreateEvent event) => _record(event);

  @override
  void onUpdate(ObservableUpdateEvent event) => _record(event);

  @override
  void onDispose(ObservableDisposeEvent event) => _record(event);

  @override
  void onTrack(TrackEvent event) => _record(event);

  @override
  void onWarning(WarningEvent event) => _record(event);

  @override
  void onEffectRun(EffectEvent event) => _record(event);
}
