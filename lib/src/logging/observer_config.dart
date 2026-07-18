import '../core/observer_inspector.dart';

/// Controls which categories of informational logs are emitted when
/// [ObserverConfig.logging] is enabled.
///
/// Controla quais categorias de logs informativos são emitidas quando
/// [ObserverConfig.logging] está habilitado.
enum ObserverLogLevel {
  /// Emits every category of log.
  ///
  /// Emite todas as categorias de log.
  all,

  /// Only value-update logs.
  ///
  /// Apenas logs de atualização de valor.
  updates,

  /// Only creation/dispose logs.
  ///
  /// Apenas logs de criação/descarte.
  lifecycle,

  /// Only Observer tracking logs.
  ///
  /// Apenas logs de rastreamento do Observer.
  tracking,
}

/// Global, mutable configuration for the package's debug behavior.
///
/// All settings are debug-only: in release builds (`kReleaseMode`) logging
/// calls are tree-shaken away regardless of these flags.
///
/// Configuração global e mutável do comportamento de debug do pacote.
///
/// Todas as configurações são exclusivas de debug: em builds de release
/// (`kReleaseMode`) as chamadas de log são eliminadas na compilação
/// independentemente destas flags.
abstract final class ObserverConfig {
  /// Whether informational logs (creation, updates, tracking, dispose) are
  /// printed. Default: `false`.
  ///
  /// Se logs informativos (criação, atualização, rastreamento, descarte)
  /// são impressos. Padrão: `false`.
  static bool logging = false;

  /// Which categories of informational logs to print when [logging] is
  /// `true`. Default: [ObserverLogLevel.all].
  ///
  /// Quais categorias de logs informativos imprimir quando [logging] for
  /// `true`. Padrão: [ObserverLogLevel.all].
  static ObserverLogLevel logLevel = ObserverLogLevel.all;

  /// Whether misuse warnings (empty Observer, writes after close, writes
  /// during build, likely leaks) are printed. Default: `true`.
  ///
  /// Se warnings de mau uso (Observer vazio, escrita após close, escrita
  /// durante build, vazamento provável) são impressos. Padrão: `true`.
  static bool warnings = true;

  /// Whether misuse cases that normally only warn instead throw an
  /// [ObserverError]: an [Observer] that reads no observable, and a write
  /// (`value =` or a collection mutation) happening during an [Observer]
  /// build. Useful in CI/tests to turn common mistakes into hard failures.
  /// Default: `false`.
  ///
  /// Se casos de mau uso que normalmente só emitem warning passam a lançar
  /// um [ObserverError]: um [Observer] que não lê nenhum observável, e uma
  /// escrita (`value =` ou mutação de coleção) acontecendo durante o build
  /// de um [Observer]. Útil em CI/testes para transformar erros comuns em
  /// falhas duras. Padrão: `false`.
  static bool strictMode = false;

  /// Listener count above which a "possible leak" warning is emitted for an
  /// observable. Default: `50`.
  ///
  /// Contagem de listeners acima da qual um warning de "possível vazamento"
  /// é emitido para um observável. Padrão: `50`.
  static int listenerLeakThreshold = 50;

  /// Whether log output uses ANSI escape codes for coloring. Disable on
  /// terminals without ANSI support. Default: `true`.
  ///
  /// Se a saída de log usa códigos de escape ANSI para colorir. Desative
  /// em terminais sem suporte a ANSI. Padrão: `true`.
  static bool useColors = true;

  /// Extra [ObserverInspector]s notified alongside the package's built-in
  /// console logging (controlled by [logging]/[warnings]/[logLevel]) for
  /// every create/update/dispose/track/warning/effect-run event. Add a
  /// `RecordingInspector` here for an in-memory audit trail, or your own
  /// implementation to forward events elsewhere (analytics, a custom log
  /// sink, ...). Default: empty.
  ///
  /// An exception thrown by one inspector is caught and isolated — it never
  /// prevents the remaining inspectors (or the built-in console logging)
  /// from running, and never breaks the notification being reported on.
  ///
  /// Inspectors extras notificados junto com o logging fixo no console do
  /// pacote (controlado por [logging]/[warnings]/[logLevel]) para todo
  /// evento de criação/atualização/descarte/rastreamento/warning/execução
  /// -de-effect. Adicione um `RecordingInspector` aqui para uma trilha de
  /// auditoria em memória, ou sua própria implementação para encaminhar
  /// eventos a outro lugar (analytics, um sink de log próprio, ...). Padrão:
  /// vazio.
  ///
  /// Uma exceção lançada por um inspector é capturada e isolada — nunca
  /// impede que os demais inspectors (ou o logging fixo no console) rodem,
  /// e nunca quebra a notificação que estava sendo reportada.
  ///
  /// This is also the single Observer Protocol registration layer. A subtype
  /// of `ObserverProtocolInspector` receives protocol events in addition to
  /// whichever legacy callbacks it overrides.
  ///
  /// Esta também é a única camada de registro do Observer Protocol. Um
  /// subtipo de `ObserverProtocolInspector` recebe eventos do protocolo além
  /// dos callbacks legados que sobrescrever.
  static List<ObserverInspector> inspectors = <ObserverInspector>[];

  /// Whether events dispatched to [inspectors] carry a captured
  /// [StackTrace]. Default: `false`, since capturing a stack trace on every
  /// event is not free — enable only while actively debugging.
  ///
  /// Se os eventos despachados para [inspectors] carregam um [StackTrace]
  /// capturado. Padrão: `false`, já que capturar um stack trace a cada
  /// evento não é gratuito — habilite apenas ao depurar ativamente.
  static bool captureStackTraces = false;

  /// Resets every setting to its default value. Intended for use between
  /// tests.
  ///
  /// Restaura todas as configurações para o valor padrão. Destinado ao uso
  /// entre testes.
  static void reset() {
    logging = false;
    logLevel = ObserverLogLevel.all;
    warnings = true;
    strictMode = false;
    listenerLeakThreshold = 50;
    useColors = true;
    inspectors = <ObserverInspector>[];
    captureStackTraces = false;
  }
}
