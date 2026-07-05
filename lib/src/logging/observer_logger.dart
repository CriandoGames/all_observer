import 'package:flutter/foundation.dart';

import '../core/core_error_reporting.dart';
import '../core/dependency_tracker.dart';
import '../core/observer_inspector.dart';
import '../errors/observer_error.dart';
import 'console_inspector.dart';
import 'observer_config.dart';

/// ANSI escape codes used by [ObserverLogger] to colorize terminal output.
///
/// Códigos de escape ANSI usados pelo [ObserverLogger] para colorir a
/// saída no terminal.
abstract final class _AnsiColor {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String blue = '\x1B[34m';
  static const String redBold = '\x1B[1;31m';
}

/// Debug-only logger for the package. Every call is guarded by `kDebugMode`
/// at the caller site and prints via [debugPrint] using [_AnsiColor] codes
/// so `flutter run` terminals render colored output.
///
/// Logger exclusivo de debug do pacote. Toda chamada é protegida por
/// `kDebugMode` no ponto de uso e imprime via [debugPrint] usando os
/// códigos de [_AnsiColor], para que o terminal do `flutter run` renderize
/// a saída colorida.
abstract final class ObserverLogger {
  static const String _prefix = '[all_observer]';

  /// The single default [ObserverInspector] instance this logger invokes
  /// directly (unconditionally, on every call to [created]/[updated]/
  /// [disposed]/[warn]) to reproduce the package's classic colored console
  /// output. See [ConsoleInspector]'s class doc for why this is separate
  /// from [ObserverConfig.inspectors] and from the `dispatch` parameter
  /// below.
  ///
  /// A única instância padrão de [ObserverInspector] que este logger invoca
  /// diretamente (incondicionalmente, a cada chamada de [created]/[updated]/
  /// [disposed]/[warn]) para reproduzir a saída colorida clássica do pacote
  /// no console. Ver o doc de classe de [ConsoleInspector] para entender por
  /// que isso é separado de [ObserverConfig.inspectors] e do parâmetro
  /// `dispatch` abaixo.
  static const ConsoleInspector _console = ConsoleInspector();

  static String _paint(String code, String text) {
    if (!ObserverConfig.useColors) {
      return text;
    }
    return '$code$text${_AnsiColor.reset}';
  }

  static String _prefixed(String body) {
    final String prefix = _paint(_AnsiColor.bold, _prefix);
    return '$prefix $body';
  }

  static bool _allowed(ObserverLogLevel level) {
    return ObserverConfig.logLevel == ObserverLogLevel.all ||
        ObserverConfig.logLevel == level;
  }

  /// Captures a [StackTrace] for the current call site if
  /// [ObserverConfig.captureStackTraces] is enabled, `null` otherwise.
  ///
  /// Captura um [StackTrace] do ponto de chamada atual se
  /// [ObserverConfig.captureStackTraces] estiver habilitado, `null` caso
  /// contrário.
  static StackTrace? _maybeStackTrace() =>
      ObserverConfig.captureStackTraces ? StackTrace.current : null;

  /// Dispatches [event] to every extra [ObserverInspector] registered via
  /// [ObserverConfig.inspectors], in addition to whatever console logging
  /// already happened. Each inspector runs inside its own `try`/`catch`: one
  /// throwing never blocks the rest, or the notification being reported on
  /// — same principle as [ListenerRegistry.notifyAll].
  ///
  /// Despacha [event] para todo [ObserverInspector] extra registrado via
  /// [ObserverConfig.inspectors], além de qualquer logging no console que já
  /// tenha acontecido. Cada inspector roda dentro do próprio `try`/`catch`:
  /// um que lança nunca bloqueia os demais, nem a notificação que estava
  /// sendo reportada — mesmo princípio de [ListenerRegistry.notifyAll].
  static void _dispatch(void Function(ObserverInspector inspector) call) {
    if (ObserverConfig.inspectors.isEmpty) {
      return;
    }
    for (final ObserverInspector inspector in List<ObserverInspector>.of(
      ObserverConfig.inspectors,
    )) {
      try {
        call(inspector);
      } catch (error) {
        if (kDebugMode) {
          debugPrint(
            _prefixed(
              _paint(
                _AnsiColor.redBold,
                '✖ ObserverInspector (${inspector.runtimeType}) lançou ao '
                'processar um evento: $error',
              ),
            ),
          );
        }
      }
    }
  }

  /// Logs the creation of an observable with its initial value.
  ///
  /// Registra a criação de um observável com seu valor inicial.
  ///
  /// [dispatch] controls whether this also fans out an
  /// `ObserverInspector.onCreate` event — pass `false` when the caller
  /// already dispatched that event itself (e.g. `CoreObservable`, wrapped by
  /// the Flutter `Observable`), to avoid every registered inspector seeing
  /// the same logical event twice.
  ///
  /// [dispatch] controla se isso também despacha um evento
  /// `ObserverInspector.onCreate` — passe `false` quando quem chamou já
  /// despachou esse evento por conta própria (ex.: `CoreObservable`,
  /// envolvido pela `Observable` do Flutter), para evitar que cada
  /// inspector registrado veja o mesmo evento lógico duas vezes.
  static void created(
    String label,
    Object? initialValue, {
    bool dispatch = true,
  }) {
    final ObservableCreateEvent event = ObservableCreateEvent(
      label,
      initialValue,
      stackTrace: _maybeStackTrace(),
    );
    if (dispatch) {
      _dispatch((ObserverInspector i) => i.onCreate(event));
    }
    _console.onCreate(event);
  }

  /// Logs a value update, showing the previous and new value.
  ///
  /// Registra uma atualização de valor, mostrando o valor anterior e o
  /// novo.
  /// See [created] for the meaning of [dispatch].
  ///
  /// Ver [created] para o significado de [dispatch].
  static void updated(
    String label,
    Object? oldValue,
    Object? newValue, {
    bool dispatch = true,
  }) {
    final ObservableUpdateEvent event = ObservableUpdateEvent(
      label,
      oldValue,
      newValue,
      stackTrace: _maybeStackTrace(),
    );
    if (dispatch) {
      _dispatch((ObserverInspector i) => i.onUpdate(event));
    }
    _console.onUpdate(event);
  }

  /// Logs the set of observables an [Observer] tracked during a build.
  ///
  /// Registra o conjunto de observáveis que um [Observer] rastreou durante
  /// um build.
  static void tracked(String label, List<String> dependencies) {
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.tracking)) {
      return;
    }
    final String deps = dependencies.join(', ');
    debugPrint(
      _prefixed(_paint(_AnsiColor.blue, '👁 $label rastreando: [$deps]')),
    );
  }

  /// Logs the disposal of an observable, including how many listeners were
  /// removed.
  ///
  /// Registra o descarte de um observável, incluindo quantos listeners
  /// foram removidos.
  /// See [created] for the meaning of [dispatch].
  ///
  /// Ver [created] para o significado de [dispatch].
  static void disposed(
    String label,
    int listenerCount, {
    bool dispatch = true,
  }) {
    final ObservableDisposeEvent event = ObservableDisposeEvent(
      label,
      listenerCount,
      stackTrace: _maybeStackTrace(),
    );
    if (dispatch) {
      _dispatch((ObserverInspector i) => i.onDispose(event));
    }
    _console.onDispose(event);
  }

  /// Installs the Flutter-side error reporter the first time it is called
  /// (idempotent — subsequent calls are a no-op), so that
  /// `CoreErrorReporting.report` calls made by the pure-Dart
  /// `ListenerRegistry`/`BatchScope` (cycle detection, isolated listener
  /// exceptions) still surface via `FlutterError.reportError` exactly as
  /// before this hook existed. Called from every place a notification can
  /// originate: [checkWriteDuringBuild] (every `value =` write and
  /// collection mutation) and `Observable.notifyListeners` (also covers a
  /// bare `refresh()` call that never went through a `value =` write).
  ///
  /// Instala o reporter do lado Flutter na primeira chamada (idempotente —
  /// chamadas seguintes são um no-op), para que chamadas de
  /// `CoreErrorReporting.report` feitas pelo `ListenerRegistry`/`BatchScope`
  /// puramente Dart (detecção de ciclo, exceções isoladas de listener) ainda
  /// cheguem via `FlutterError.reportError` exatamente como antes deste
  /// gancho existir. Chamado em todo lugar de onde uma notificação pode se
  /// originar: [checkWriteDuringBuild] (toda escrita `value =` e mutação de
  /// coleção) e `Observable.notifyListeners` (cobre também uma chamada
  /// avulsa a `refresh()` que nunca passou por uma escrita `value =`).
  static void ensureErrorReporterInstalled() {
    CoreErrorReporting.reporter ??=
        (
          Object error,
          StackTrace stackTrace, {
          required String library,
          required String context,
        }) {
          caughtException(context, error);
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: library,
              context: ErrorDescription(context),
            ),
          );
        };
  }

  /// Checks whether a write/mutation is happening while an [Observer] (or
  /// any tracked builder) is currently running, and reacts accordingly:
  /// when [ObserverConfig.strictMode] is `true`, throws an [ObserverError]
  /// instead of only warning — useful in CI/tests to turn this common
  /// mistake into a hard failure. Otherwise emits the usual non-fatal
  /// warning. Used by both [Observable.value]'s setter and every reactive
  /// collection's mutating members, so the check covers `value =`
  /// reassignment as well as collection mutations (`add`, `addAll`,
  /// `clear`, ...).
  ///
  /// Verifica se uma escrita/mutação está ocorrendo enquanto um [Observer]
  /// (ou qualquer builder rastreado) está em execução, e reage de acordo:
  /// quando [ObserverConfig.strictMode] for `true`, lança um
  /// [ObserverError] em vez de apenas emitir warning — útil em CI/testes
  /// para transformar esse erro comum em falha dura. Caso contrário, emite
  /// o warning não fatal de sempre. Usado tanto pelo setter de
  /// [Observable.value] quanto por todo membro mutante das coleções
  /// reativas, então a checagem cobre tanto a reatribuição de `value =`
  /// quanto mutações de coleção (`add`, `addAll`, `clear`, ...).
  static void checkWriteDuringBuild(String label) {
    ensureErrorReporterInstalled();
    if (DependencyTracker.current == null) {
      return;
    }
    final String message = '$label alterado DURANTE o build de um Observer.';
    if (ObserverConfig.strictMode) {
      throw ObserverError(message);
    }
    if (!kDebugMode) {
      return;
    }
    warn(
      message,
      suggestion:
          'Isso causa loop de rebuild. Mova a alteração para '
          'fora do build.',
    );
  }

  /// Logs, in red, a one-line summary of an exception the package caught
  /// and isolated (e.g. a listener that threw during notification). This is
  /// printed *in addition to* the standard [FlutterError.reportError] call
  /// the caller also makes — that call still reaches the host app's own
  /// error reporting (Crashlytics, Sentry, the default framework console
  /// dump, ...) uncolored, exactly as Flutter prints it for any other
  /// package. This method only adds a package-colored line on top; it does
  /// not touch [FlutterError.onError], so it never interferes with how the
  /// host app handles its own errors.
  ///
  /// Registra, em vermelho, um resumo de uma linha de uma exceção que o
  /// pacote capturou e isolou (por exemplo, um listener que lançou durante
  /// a notificação). Isso é impresso *além* da chamada padrão a
  /// [FlutterError.reportError] que quem chama também faz — essa chamada
  /// continua chegando ao próprio sistema de relato de erros do app
  /// hospedeiro (Crashlytics, Sentry, o dump padrão do framework no
  /// console, ...) sem cor, exatamente como o Flutter imprime para
  /// qualquer outro pacote. Este método só adiciona uma linha colorida do
  /// pacote por cima; ele não mexe em [FlutterError.onError], então nunca
  /// interfere em como o app hospedeiro trata seus próprios erros.
  static void caughtException(String context, Object error) {
    if (!kDebugMode || !ObserverConfig.warnings) {
      return;
    }
    debugPrint(_prefixed(_paint(_AnsiColor.redBold, '✖ $context: $error')));
  }

  /// Logs a misuse warning with an optional indented suggestion line.
  ///
  /// Registra um warning de mau uso, com uma linha de sugestão indentada
  /// opcional.
  /// See [created] for the meaning of [dispatch].
  ///
  /// Ver [created] para o significado de [dispatch].
  static void warn(String message, {String? suggestion, bool dispatch = true}) {
    final WarningEvent event = WarningEvent(
      message,
      suggestion: suggestion,
      stackTrace: _maybeStackTrace(),
    );
    if (dispatch) {
      _dispatch((ObserverInspector i) => i.onWarning(event));
    }
    _console.onWarning(event);
  }
}
