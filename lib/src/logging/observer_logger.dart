import 'package:flutter/foundation.dart';

import '../core/dependency_tracker.dart';
import '../core/observer_inspector.dart';
import '../errors/observer_error.dart';
import 'observer_config.dart';

/// ANSI escape codes used by [ObserverLogger] to colorize terminal output.
///
/// Códigos de escape ANSI usados pelo [ObserverLogger] para colorir a
/// saída no terminal.
abstract final class _AnsiColor {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String green = '\x1B[32m';
  static const String cyan = '\x1B[36m';
  static const String blue = '\x1B[34m';
  static const String gray = '\x1B[90m';
  static const String yellowBold = '\x1B[1;33m';
  static const String magenta = '\x1B[35m';
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
  static void created(String label, Object? initialValue) {
    _dispatch(
      (ObserverInspector i) => i.onCreate(
        ObservableCreateEvent(
          label,
          initialValue,
          stackTrace: _maybeStackTrace(),
        ),
      ),
    );
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.lifecycle)) {
      return;
    }
    final String value = _paint(_AnsiColor.magenta, '$initialValue');
    debugPrint(_prefixed(_paint(_AnsiColor.green, '✚ $label criado → $value')));
  }

  /// Logs a value update, showing the previous and new value.
  ///
  /// Registra uma atualização de valor, mostrando o valor anterior e o
  /// novo.
  static void updated(String label, Object? oldValue, Object? newValue) {
    _dispatch(
      (ObserverInspector i) => i.onUpdate(
        ObservableUpdateEvent(
          label,
          oldValue,
          newValue,
          stackTrace: _maybeStackTrace(),
        ),
      ),
    );
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.updates)) {
      return;
    }
    final String values = _paint(_AnsiColor.magenta, '$oldValue → $newValue');
    debugPrint(_prefixed(_paint(_AnsiColor.cyan, '↻ $label: $values')));
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
  static void disposed(String label, int listenerCount) {
    _dispatch(
      (ObserverInspector i) => i.onDispose(
        ObservableDisposeEvent(
          label,
          listenerCount,
          stackTrace: _maybeStackTrace(),
        ),
      ),
    );
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.lifecycle)) {
      return;
    }
    debugPrint(
      _prefixed(
        _paint(
          _AnsiColor.gray,
          '✖ $label descartado ($listenerCount '
          'listeners removidos)',
        ),
      ),
    );
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
  static void warn(String message, {String? suggestion}) {
    _dispatch(
      (ObserverInspector i) => i.onWarning(
        WarningEvent(
          message,
          suggestion: suggestion,
          stackTrace: _maybeStackTrace(),
        ),
      ),
    );
    if (!ObserverConfig.warnings) {
      return;
    }
    final StringBuffer buffer = StringBuffer(
      _prefixed(_paint(_AnsiColor.yellowBold, '⚠ $message')),
    );
    if (suggestion != null) {
      buffer.write('\n    ${_paint(_AnsiColor.yellowBold, suggestion)}');
    }
    debugPrint(buffer.toString());
  }
}
