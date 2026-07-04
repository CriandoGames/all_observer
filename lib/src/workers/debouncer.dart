import 'dart:async';

/// Minimal debounce/throttle helper used by the `debounce` and `interval`
/// workers. Kept tiny and self-contained so `workers.dart` stays focused
/// on wiring, not timer bookkeeping.
///
/// Auxiliar mínimo de debounce/throttle usado pelos workers `debounce` e
/// `interval`. Mantido pequeno e autocontido para que `workers.dart` fique
/// focado na fiação, não no controle de timers.
class Debouncer {
  /// Creates a debouncer that waits [duration] of inactivity before
  /// running the scheduled action.
  ///
  /// Cria um debouncer que aguarda [duration] de inatividade antes de
  /// executar a ação agendada.
  Debouncer(this.duration);

  /// How long to wait after the last [run] call before invoking the
  /// action.
  ///
  /// Quanto tempo aguardar após a última chamada a [run] antes de invocar
  /// a ação.
  final Duration duration;

  Timer? _timer;

  /// Schedules [action], canceling any previously scheduled one.
  ///
  /// Agenda [action], cancelando qualquer uma previamente agendada.
  void run(void Function() action) {
    _timer?.cancel();
    _timer = Timer(duration, action);
  }

  /// Cancels any pending scheduled action.
  ///
  /// Cancela qualquer ação agendada pendente.
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
