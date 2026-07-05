/// Thrown/reported (via `CoreErrorReporting`) when the package detects a
/// possible update cycle — a listener of one observable writing to another
/// whose listener writes back, forever — and aborts instead of recursing or
/// looping indefinitely. See `kMaxNotificationDepth` (recursive call-stack
/// cycles, outside any batch) and `kMaxFlushWaves` (iterative cycles inside
/// an `Observable.batch()`).
///
/// This is a plain Dart [Error] (not a Flutter `FlutterError`) so the core
/// files that detect these cycles (`ListenerRegistry`, `BatchScope`) do not
/// need to depend on Flutter — the Flutter layer still wraps this in a
/// `FlutterErrorDetails` before forwarding it to
/// `FlutterError.reportError`, so it surfaces to a Flutter app's error
/// reporting exactly as before.
///
/// Lançado/reportado (via `CoreErrorReporting`) quando o pacote detecta um
/// possível ciclo de atualização — um listener de um observável escrevendo
/// em outro cujo listener escreve de volta, indefinidamente — e aborta em
/// vez de recursar ou entrar em loop para sempre. Ver `kMaxNotificationDepth`
/// (ciclos recursivos na pilha de chamadas, fora de qualquer batch) e
/// `kMaxFlushWaves` (ciclos iterativos dentro de um `Observable.batch()`).
///
/// Este é um [Error] Dart puro (não um `FlutterError`), então os arquivos do
/// core que detectam esses ciclos (`ListenerRegistry`, `BatchScope`) não
/// precisam depender de Flutter — a camada Flutter continua envolvendo isto
/// em um `FlutterErrorDetails` antes de encaminhar para
/// `FlutterError.reportError`, então ele chega ao relato de erros de um app
/// Flutter exatamente como antes.
class ObserverCycleError extends Error {
  /// Creates an [ObserverCycleError] with a human-readable [message].
  ///
  /// Cria um [ObserverCycleError] com uma [message] legível por humanos.
  ObserverCycleError(this.message);

  /// Explanation of the detected cycle.
  ///
  /// Explicação do ciclo detectado.
  final String message;

  @override
  String toString() => 'ObserverCycleError: $message';
}
