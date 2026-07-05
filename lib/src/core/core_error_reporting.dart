/// Pure-Dart hook the core uses to surface an exception it caught and
/// isolated (a listener/`Computed`/`Effect` that threw, or a detected update
/// cycle) to whatever hosting framework/tooling is present, without the core
/// itself depending on Flutter.
///
/// The Flutter layer (`ObserverLogger`) installs [reporter] the first time a
/// write happens, forwarding to `FlutterError.reportError` — this preserves
/// the exact same visible behavior Flutter apps had before this hook
/// existed. In a pure-Dart context (`package:all_observer/core.dart` only,
/// no Flutter loaded), [reporter] stays `null` and these exceptions are only
/// silently isolated, unless you install your own [reporter].
///
/// Gancho puro em Dart que o core usa para expor uma exceção que capturou e
/// isolou (um listener/`Computed`/`Effect` que lançou, ou um ciclo de
/// atualização detectado) para qualquer framework/ferramental hospedeiro
/// presente, sem que o próprio core dependa de Flutter.
///
/// A camada Flutter (`ObserverLogger`) instala [reporter] na primeira
/// escrita que acontecer, encaminhando para `FlutterError.reportError` —
/// isso preserva exatamente o mesmo comportamento visível que apps Flutter
/// tinham antes deste gancho existir. Em um contexto Dart puro
/// (`package:all_observer/core.dart` apenas, sem Flutter carregado),
/// [reporter] permanece `null` e essas exceções só são isoladas
/// silenciosamente, a menos que você instale seu próprio [reporter].
abstract final class CoreErrorReporting {
  /// The installed reporter, if any. Set this yourself in a pure-Dart
  /// context to receive these exceptions; the Flutter layer sets it
  /// automatically otherwise.
  ///
  /// O reporter instalado, se houver. Defina-o você mesmo em um contexto
  /// Dart puro para receber essas exceções; a camada Flutter o define
  /// automaticamente caso contrário.
  static void Function(
    Object error,
    StackTrace stackTrace, {
    required String library,
    required String context,
  })?
  reporter;

  /// Reports [error]/[stackTrace] via [reporter], if one is installed.
  /// No-op otherwise.
  ///
  /// Reporta [error]/[stackTrace] via [reporter], se houver um instalado.
  /// No-op caso contrário.
  static void report(
    Object error,
    StackTrace stackTrace, {
    required String library,
    required String context,
  }) {
    reporter?.call(error, stackTrace, library: library, context: context);
  }
}
