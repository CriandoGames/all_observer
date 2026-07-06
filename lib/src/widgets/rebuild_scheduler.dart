import 'package:flutter/scheduler.dart';

/// Shared rebuild-scheduling helper for every widget-facing consumer of the
/// dependency tracker (`Observer`'s `_onDependencyChanged` and
/// `watch(context)`'s `_ElementWatcher`): runs [rebuild] immediately when it
/// is safe to mark widgets dirty, or defers it to a post-frame callback when
/// the notification arrived during the build/layout/paint phase
/// ([SchedulerPhase.persistentCallbacks]) — marking an element dirty in that
/// phase is forbidden by the framework and would throw.
///
/// [isMounted] is consulted twice: before doing anything (a notification for
/// an already-unmounted consumer is a no-op), and again inside the deferred
/// post-frame callback (the consumer may have unmounted while the frame
/// finished).
///
/// Helper compartilhado de agendamento de rebuild para todo consumidor do
/// rastreador de dependências no lado dos widgets (o `_onDependencyChanged`
/// do `Observer` e o `_ElementWatcher` do `watch(context)`): executa
/// [rebuild] imediatamente quando é seguro marcar widgets como sujos, ou o
/// adia para um callback pós-frame quando a notificação chegou durante a
/// fase de build/layout/paint ([SchedulerPhase.persistentCallbacks]) —
/// marcar um element como sujo nessa fase é proibido pelo framework e
/// lançaria uma exceção.
///
/// [isMounted] é consultado duas vezes: antes de qualquer coisa (uma
/// notificação para um consumidor já desmontado é um no-op), e de novo
/// dentro do callback pós-frame adiado (o consumidor pode ter sido
/// desmontado enquanto o frame terminava).
void scheduleRebuildRespectingPhase({
  required bool Function() isMounted,
  required void Function() rebuild,
}) {
  if (!isMounted()) {
    return;
  }
  final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
  if (phase == SchedulerPhase.persistentCallbacks) {
    SchedulerBinding.instance.addPostFrameCallback((Duration _) {
      if (isMounted()) {
        rebuild();
      }
    });
  } else {
    rebuild();
  }
}
