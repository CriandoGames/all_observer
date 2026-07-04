import 'listener_registry.dart';

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
  static final Set<ListenerRegistry> _pending = <ListenerRegistry>{};

  /// Whether a `batch()` call is currently active (depth > 0). While `true`,
  /// [ListenerRegistry.notifyAll] calls made through
  /// [ListenerRegistry.notifyOrQueue] are deferred instead of running
  /// immediately.
  ///
  /// Se uma chamada `batch()` está atualmente ativa (profundidade > 0).
  /// Enquanto `true`, chamadas a [ListenerRegistry.notifyAll] feitas via
  /// [ListenerRegistry.notifyOrQueue] são adiadas em vez de rodarem
  /// imediatamente.
  static bool get isActive => _depth > 0;

  /// Queues [registry] to be notified once when the outermost batch ends.
  ///
  /// Enfileira [registry] para ser notificado uma única vez quando o batch
  /// mais externo terminar.
  static void queue(ListenerRegistry registry) => _pending.add(registry);

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
      }
      rethrow;
    } finally {
      _depth--;
      if (_depth == 0 && _pending.isNotEmpty) {
        final List<ListenerRegistry> toNotify = List<ListenerRegistry>.of(
          _pending,
        );
        _pending.clear();
        for (final ListenerRegistry registry in toNotify) {
          registry.notifyAll();
        }
      }
    }
  }
}
