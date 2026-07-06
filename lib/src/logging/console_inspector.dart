import 'package:flutter/foundation.dart';

import '../core/observer_inspector.dart';
import 'observer_config.dart';

/// ANSI escape codes used by [ConsoleInspector] to colorize terminal output.
/// Kept as its own tiny private copy so this file has no dependency on
/// `ObserverLogger`'s internals.
///
/// Códigos de escape ANSI usados por [ConsoleInspector] para colorir a saída
/// no terminal. Mantido como uma cópia própria e pequena, para que este
/// arquivo não dependa dos internals de `ObserverLogger`.
abstract final class _AnsiColor {
  static const String reset = '\x1B[0m';
  static const String bold = '\x1B[1m';
  static const String green = '\x1B[32m';
  static const String cyan = '\x1B[36m';
  static const String gray = '\x1B[90m';
  static const String yellowBold = '\x1B[1;33m';
  static const String magenta = '\x1B[35m';
}

/// The default [ObserverInspector] implementation: reproduces the package's
/// classic colored console logging (creation, updates, dispose, warnings)
/// that shipped before [ObserverInspector] existed.
///
/// `ObserverLogger` holds a single internal `const ConsoleInspector()` and
/// invokes it directly — unconditionally, on every call — gated only by
/// [ObserverConfig.logging]/[ObserverConfig.warnings]/
/// [ObserverConfig.logLevel]/[ObserverConfig.useColors], exactly as the
/// hardcoded printing worked before this class existed. It is deliberately
/// **not** added to [ObserverConfig.inspectors]: that list is for *extra*,
/// user-registered inspectors, and a call's `dispatch: false` (used by
/// `Observable`/`Computed` to avoid double-notifying `inspectors` when the
/// underlying `CoreObservable`/`CoreComputed` already dispatched the event)
/// only skips *that* fan-out — this console output always still runs,
/// self-gated the same way it always was. Net effect: registering your own
/// inspectors never changes, duplicates, or silences the default console
/// output.
///
/// Also usable standalone — e.g. forwarding events from a pure-Dart
/// `CoreObservable`/`CoreComputed` in a CLI context via
/// `package:all_observer/core.dart` — by registering `const
/// ConsoleInspector()` in that context's own inspector list. In that path it
/// *does* go through the list you control, so add it only once to avoid
/// duplicate lines.
///
/// A implementação padrão de [ObserverInspector]: reproduz o logging
/// colorido clássico no console (criação, atualizações, descarte, warnings)
/// que já existia antes de [ObserverInspector] existir.
///
/// `ObserverLogger` mantém uma única `const ConsoleInspector()` interna e a
/// invoca diretamente — incondicionalmente, a cada chamada — controlada
/// apenas por [ObserverConfig.logging]/[ObserverConfig.warnings]/
/// [ObserverConfig.logLevel]/[ObserverConfig.useColors], exatamente como a
/// impressão fixa funcionava antes desta classe existir. Ela deliberadamente
/// **não** é adicionada a [ObserverConfig.inspectors]: essa lista é para
/// inspectors *extras*, registrados pelo usuário, e o `dispatch: false` de
/// uma chamada (usado por `Observable`/`Computed` para evitar notificar
/// `inspectors` duas vezes quando o `CoreObservable`/`CoreComputed`
/// subjacente já despachou o evento) só pula *esse* fan-out — esta saída no
/// console continua sempre rodando, autocontrolada como sempre foi. Efeito
/// líquido: registrar seus próprios inspectors nunca muda, duplica ou
/// silencia a saída padrão no console.
///
/// Também utilizável de forma autônoma — ex.: encaminhando eventos de um
/// `CoreObservable`/`CoreComputed` em Dart puro num contexto de CLI via
/// `package:all_observer/core.dart` — registrando `const ConsoleInspector()`
/// na lista de inspectors própria desse contexto. Nesse caminho ela *passa*
/// pela lista que você controla, então adicione-a apenas uma vez para evitar
/// linhas duplicadas.
class ConsoleInspector implements ObserverInspector {
  /// Creates a [ConsoleInspector]. Stateless — safe to share a single
  /// `const` instance.
  ///
  /// Cria um [ConsoleInspector]. Sem estado — seguro compartilhar uma única
  /// instância `const`.
  const ConsoleInspector();

  static String _paint(String code, String text) {
    if (!ObserverConfig.useColors) {
      return text;
    }
    return '$code$text${_AnsiColor.reset}';
  }

  static String _prefixed(String body) {
    final String prefix = _paint(_AnsiColor.bold, '[all_observer]');
    return '$prefix $body';
  }

  static bool _allowed(ObserverLogLevel level) {
    return ObserverConfig.logLevel == ObserverLogLevel.all ||
        ObserverConfig.logLevel == level;
  }

  @override
  void onCreate(ObservableCreateEvent event) {
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.lifecycle)) {
      return;
    }
    final String value = _paint(_AnsiColor.magenta, '${event.initialValue}');
    debugPrint(
      _prefixed(_paint(_AnsiColor.green, '✚ ${event.label} criado → $value')),
    );
  }

  @override
  void onUpdate(ObservableUpdateEvent event) {
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.updates)) {
      return;
    }
    final String values = _paint(
      _AnsiColor.magenta,
      '${event.oldValue} → ${event.newValue}',
    );
    debugPrint(_prefixed(_paint(_AnsiColor.cyan, '↻ ${event.label}: $values')));
  }

  @override
  void onDispose(ObservableDisposeEvent event) {
    if (!ObserverConfig.logging || !_allowed(ObserverLogLevel.lifecycle)) {
      return;
    }
    debugPrint(
      _prefixed(
        _paint(
          _AnsiColor.gray,
          '✖ ${event.label} descartado (${event.listenerCount} '
          'listeners removidos)',
        ),
      ),
    );
  }

  @override
  void onWarning(WarningEvent event) {
    if (!ObserverConfig.warnings) {
      return;
    }
    final StringBuffer buffer = StringBuffer(
      _prefixed(_paint(_AnsiColor.yellowBold, '⚠ ${event.label}')),
    );
    if (event.suggestion != null) {
      buffer.write('\n    ${_paint(_AnsiColor.yellowBold, event.suggestion!)}');
    }
    debugPrint(buffer.toString());
  }

  @override
  void onTrack(TrackEvent event) {
    // Observer's per-build "tracked dependencies" summary
    // (`ObserverLogger.tracked`) is a separate, aggregate log — one line per
    // build listing every dependency — not a 1:1 mapping to this
    // per-dependency event, so it stays exactly where it is. This is a
    // no-op to avoid mismatched/duplicate console output.
    //
    // O resumo por build de "dependências rastreadas" do Observer
    // (`ObserverLogger.tracked`) é um log agregado separado — uma linha por
    // build listando cada dependência — não um mapeamento 1:1 para este
    // evento por dependência, então ele continua exatamente onde está. Isto
    // é um no-op para evitar saída duplicada/incompatível no console.
  }

  @override
  void onEffectRun(EffectEvent event) {
    // No console output existed for effect runs before ObserverInspector
    // was introduced, so this stays silent by default to keep the default
    // visible behavior identical to before. Register your own
    // ObserverInspector via ObserverConfig.inspectors if you want to log
    // these.
    //
    // Nenhuma saída de console existia para execuções de effect antes de
    // ObserverInspector ser introduzido, então isto permanece silencioso por
    // padrão, para manter o comportamento visível padrão idêntico a antes.
    // Registre seu próprio ObserverInspector via ObserverConfig.inspectors
    // se quiser registrar essas execuções.
  }

  @override
  void onScopeDispose(ScopeDisposeEvent event) {
    // Scope disposal is silent by default for the same reason as
    // onEffectRun above: no console output existed for it before the event
    // was introduced, so the default visible behavior stays identical.
    // Register your own ObserverInspector via ObserverConfig.inspectors if
    // you want to log these.
    //
    // O descarte de escopo é silencioso por padrão pelo mesmo motivo de
    // onEffectRun acima: nenhuma saída de console existia para ele antes
    // do evento ser introduzido, então o comportamento visível padrão
    // permanece idêntico. Registre seu próprio ObserverInspector via
    // ObserverConfig.inspectors se quiser registrar esses descartes.
  }
}
