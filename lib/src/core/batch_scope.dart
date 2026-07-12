import '../errors/observer_cycle_error.dart';
import 'core_error_reporting.dart';
import 'listener_registry.dart';

/// Maximum number of flush waves (full drain cycles of `_pending` +
/// `_dirtyFlushCallbacks`) before [BatchScope._flushPending] aborts with a
/// descriptive error. Each wave corresponds to one complete pass where every
/// pending registry and every dirty-flush callback run; a legitimate
/// notification cascade needs as many waves as the longest dependency chain.
/// 100 is far more than any real-world graph depth and keeps the total work
/// bounded.
///
/// Número máximo de ondas de flush (ciclos completos de drenagem de
/// `_pending` + `_dirtyFlushCallbacks`) antes que
/// [BatchScope._flushPending] aborte com um erro descritivo. Cada onda
/// corresponde a uma passagem completa em que todos os registros pendentes
/// e todos os callbacks de flush sujo são executados; uma cascata de
/// notificações legítima precisa de tantas ondas quanto a profundidade da
/// cadeia de dependências mais longa. 100 é muito mais do que qualquer
/// profundidade real de grafo e mantém o trabalho total limitado.
const int kMaxFlushWaves = 100;

/// Tracks the currently active `Observable.batch()` nesting depth and the
/// set of [ListenerRegistry]s pending notification once the outermost batch
/// completes.
///
/// Supports nested batches via a depth counter: only the outermost
/// `batch()` call actually flushes pending notifications, so a nested
/// `batch()` call is a no-op with respect to flushing. Pending registries
/// are deduplicated (a `Set`), so an observable written multiple times
/// inside the same batch still notifies exactly once.
///
/// Rastreia a profundidade de aninhamento atual de `Observable.batch()` e o
/// conjunto de [ListenerRegistry]s pendentes de notificação assim que o
/// batch mais externo terminar.
///
/// Suporta batches aninhados via um contador de profundidade: apenas a
/// chamada `batch()` mais externa de fato libera as notificações
/// pendentes, então uma chamada `batch()` aninhada é um no-op quanto ao
/// flush. Os registros pendentes são deduplicados (um `Set`), então um
/// observável escrito múltiplas vezes dentro do mesmo batch ainda assim
/// notifica exatamente uma vez.
abstract final class BatchScope {
  static int _depth = 0;
  static bool _flushing = false;
  static int _flushEpoch = 0;
  static final Set<ListenerRegistry> _pending = <ListenerRegistry>{};
  static final Set<void Function()> _dirtyFlushCallbacks = <void Function()>{};

  /// Monotonic identifier for the currently running batch flush. Intended for
  /// internal schedulers that need to distinguish invalidations from the same
  /// flush wave from future external writes.
  ///
  /// Identificador monotônico do flush de batch em execução. Destinado a
  /// schedulers internos que precisam distinguir invalidações do mesmo flush
  /// de escritas externas futuras.
  static int get flushEpoch => _flushEpoch;

  /// Whether a `batch()` call is currently active (depth > 0), OR the
  /// outermost `batch()` call is currently flushing its queued
  /// notifications/recomputes. The latter matters for [Computed]: a
  /// recompute triggered *during* the flush (e.g. `doubled` recomputing and
  /// notifying `sum`, which in turn depends on `tripled` too) must still
  /// defer instead of running eagerly, or the diamond glitch would simply
  /// move one level down the cascade instead of being fixed. See
  /// [_flushPending] for the fixed-point loop this enables.
  ///
  /// Se uma chamada `batch()` está atualmente ativa (profundidade > 0), OU a
  /// chamada `batch()` mais externa está atualmente fazendo flush de suas
  /// notificações/recomputes enfileirados. O segundo caso importa para
  /// [Computed]: um recompute disparado *durante* o flush (ex.: `doubled`
  /// recalculando e notificando `sum`, que por sua vez também depende de
  /// `tripled`) ainda precisa adiar em vez de rodar avidamente, ou o glitch
  /// do diamante simplesmente se moveria um nível abaixo na cascata em vez
  /// de ser corrigido. Ver [_flushPending] para o loop de ponto fixo que
  /// isso viabiliza.
  static bool get isActive => _depth > 0 || _flushing;

  /// Queues [registry] to be notified once when the outermost batch ends.
  ///
  /// Enfileira [registry] para ser notificado uma única vez quando o batch
  /// mais externo terminar.
  static void queue(ListenerRegistry registry) => _pending.add(registry);

  /// Queues [callback] (deduplicated) to run once, after every pending
  /// [ListenerRegistry] has already been flushed, when the outermost batch
  /// ends. Used by [Computed] to recompute (and, if changed, notify) marked
  /// -dirty derived values exactly once per batch, after all of their
  /// upstream dependencies have already settled to their final value — see
  /// the "diamond glitch" note on `Computed`'s class doc.
  ///
  /// Enfileira [callback] (deduplicado) para rodar uma vez, depois que todo
  /// [ListenerRegistry] pendente já tiver sido esvaziado, quando o batch
  /// mais externo terminar. Usado por [Computed] para recalcular (e, se
  /// mudou, notificar) valores derivados marcados como sujos exatamente uma
  /// vez por batch, depois que todas as suas dependências a montante já
  /// tiverem se estabilizado no valor final — ver a nota sobre "glitch do
  /// diamante" no doc da classe `Computed`.
  static void queueDirtyFlush(void Function() callback) {
    _dirtyFlushCallbacks.add(callback);
  }

  /// Runs [action] inside a batch: writes to any [Observable] or reactive
  /// collection during [action] are coalesced so every distinct changed
  /// observable notifies its listeners exactly once, after [action]
  /// returns. Nested calls are supported — only the outermost call flushes.
  ///
  /// If [action] throws, the depth counter is still restored (via
  /// `finally`); the pending queue built up so far is discarded without
  /// notifying anyone. This is a deliberate, documented choice: a batch
  /// that fails partway through is treated as not having completed, so
  /// listeners never observe an inconsistent partial update.
  ///
  /// Executa [action] dentro de um batch: escritas em qualquer [Observable]
  /// ou coleção reativa durante [action] são agrupadas, de forma que cada
  /// observável distinto alterado notifique seus listeners exatamente uma
  /// vez, após [action] retornar. Chamadas aninhadas são suportadas —
  /// apenas a chamada mais externa libera o flush.
  ///
  /// Se [action] lançar uma exceção, o contador de profundidade ainda é
  /// restaurado (via `finally`); a fila pendente construída até então é
  /// descartada sem notificar ninguém. Esta é uma escolha deliberada e
  /// documentada: um batch que falha no meio do caminho é tratado como não
  /// tendo sido concluído, então os listeners nunca observam uma
  /// atualização parcial inconsistente.
  static void run(void Function() action) {
    _depth++;
    try {
      action();
    } catch (_) {
      if (_depth == 1) {
        _pending.clear();
        _dirtyFlushCallbacks.clear();
      }
      rethrow;
    } finally {
      _depth--;
      if (_depth == 0) {
        _flushPending();
      }
    }
  }

  // Drains `_pending` (plain Observable/collection notifications) and
  // `_dirtyFlushCallbacks` (deferred Computed recomputes) as a single
  // fixed-point work queue, with `isActive` (via `_flushing`) kept `true`
  // for its entire duration.
  //
  // This matters for cascades more than one Computed deep: `source`
  // notifying `doubled`/`tripled` (which mark themselves dirty and stop
  // there) is only half the story — flushing `doubled`'s dirty flag
  // recomputes it and notifies `sum`, and if `isActive` had already gone
  // back to `false` by then, `sum` would recompute right there, still
  // having only seen `doubled`'s new value and `tripled`'s stale one (the
  // exact glitch this whole mechanism exists to prevent — just moved one
  // level down the graph). Keeping `isActive` true across every wave means
  // `sum` instead marks itself dirty too, and only actually recomputes once
  // both `doubled` and `tripled` have already settled and notified it,
  // in a later wave of this same loop.
  //
  // Esvazia `_pending` (notificações de Observable/coleção comuns) e
  // `_dirtyFlushCallbacks` (recomputes de Computed adiados) como uma única
  // fila de trabalho de ponto fixo, com `isActive` (via `_flushing`)
  // mantido `true` durante toda a sua duração.
  //
  // Isso importa para cascatas com mais de um `Computed` de profundidade:
  // `source` notificar `doubled`/`tripled` (que se marcam como sujos e
  // param por aí) é só metade da história — esvaziar o sinal de sujo de
  // `doubled` o recalcula e notifica `sum`, e se `isActive` já tivesse
  // voltado a `false` nesse ponto, `sum` recalcularia ali mesmo, tendo
  // visto apenas o novo valor de `doubled` e o valor ainda desatualizado de
  // `tripled` (exatamente o glitch que este mecanismo existe para evitar —
  // só que um nível abaixo no grafo). Manter `isActive` como `true` durante
  // todas as ondas faz com que `sum` também se marque como sujo, e só
  // recalcule de fato depois que `doubled` e `tripled` já tiverem se
  // estabilizado e o notificado, em uma onda posterior deste mesmo loop.
  static void _flushPending() {
    _flushing = true;
    _flushEpoch++;
    int waves = 0;
    try {
      while (_pending.isNotEmpty || _dirtyFlushCallbacks.isNotEmpty) {
        // Guard against infinite loops caused by mutual cycles inside a
        // batch (e.g. `a.listen((v) => b.value = v + 1)` combined with
        // `b.listen((v) => a.value = v + 1)` both inside the same batch).
        // Unlike `kMaxNotificationDepth` — which caps *nested call-stack*
        // recursion — this caps iterative `while` waves, which is the form
        // that in-batch cycles take after the batch transform them from
        // recursive calls into queued re-notifications.
        //
        // Protege contra loops infinitos causados por ciclos mútuos dentro
        // de um batch (ex.: `a.listen((v) => b.value = v + 1)` combinado
        // com `b.listen((v) => a.value = v + 1)` ambos dentro do mesmo
        // batch). Diferente de `kMaxNotificationDepth` — que limita a
        // *recursão aninhada na pilha de chamadas* — este limita as ondas
        // iterativas do `while`, que é a forma que os ciclos dentro de um
        // batch assumem após o batch transformá-los de chamadas recursivas
        // em re-notificações enfileiradas.
        if (waves >= kMaxFlushWaves) {
          final ObserverCycleError waveError = ObserverCycleError(
            'all_observer: possível ciclo de atualização dentro de um '
            'batch detectado. O número de ondas de flush excedeu '
            '$kMaxFlushWaves (um listener de um observável escreve em '
            'outro cujo listener escreve de volta, em loop). Interrompendo '
            'o flush e descartando as notificações restantes em vez de '
            'travar indefinidamente. / Possible in-batch update cycle '
            'detected: flush wave count exceeded $kMaxFlushWaves. '
            'Aborting flush and discarding remaining notifications.',
          );
          CoreErrorReporting.report(
            waveError,
            StackTrace.current,
            library: 'all_observer',
            context:
                'ciclo de atualização dentro de batch — ondas '
                'excedidas — while flushing a batch — possible in-batch '
                'update cycle',
          );
          _pending.clear();
          _dirtyFlushCallbacks.clear();
          break;
        }
        waves++;

        if (_pending.isNotEmpty) {
          final List<ListenerRegistry> toNotify = List<ListenerRegistry>.of(
            _pending,
          );
          _pending.clear();
          for (final ListenerRegistry registry in toNotify) {
            registry.notifyAll();
          }
        }
        if (_dirtyFlushCallbacks.isNotEmpty) {
          final List<void Function()> toFlush = List<void Function()>.of(
            _dirtyFlushCallbacks,
          );
          _dirtyFlushCallbacks.clear();
          // Each callback runs in its own try/catch, mirroring
          // ListenerRegistry.notifyAll: a Computed whose `compute` throws
          // during a deferred batch-flush recompute must not abort the rest
          // of this fixed-point loop, or every other still-pending
          // dirty/pending entry (already removed from the sets above) would
          // silently never run.
          //
          // Cada callback roda em seu próprio try/catch, espelhando
          // ListenerRegistry.notifyAll: um Computed cujo `compute` lança
          // durante um recompute de flush de batch adiado não pode abortar o
          // resto deste loop de ponto fixo, ou toda outra entrada
          // dirty/pending ainda pendente (já removida dos conjuntos acima)
          // nunca rodaria silenciosamente.
          for (final void Function() callback in toFlush) {
            try {
              callback();
            } catch (error, stackTrace) {
              CoreErrorReporting.report(
                error,
                stackTrace,
                library: 'all_observer',
                context:
                    'exceção isolada em um recompute de Computed '
                    'adiado por batch — while flushing a batch-deferred '
                    'Computed recompute',
              );
            }
          }
        }
      }
    } finally {
      _flushing = false;
    }
  }
}
