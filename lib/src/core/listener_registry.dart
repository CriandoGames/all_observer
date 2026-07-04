import 'dart:collection' show LinkedHashSet;

import 'package:flutter/foundation.dart';

import '../logging/observer_logger.dart';
import 'batch_scope.dart';
import 'typedefs.dart';

/// Maximum notification depth allowed before [ListenerRegistry.notifyAll]
/// aborts with a descriptive error instead of overflowing the call stack.
/// Guards against update cycles (a listener of A writing B, whose listener
/// writes back to A, forever).
///
/// Profundidade máxima de notificação permitida antes que
/// [ListenerRegistry.notifyAll] aborte com um erro descritivo em vez de
/// estourar a pilha de chamadas. Protege contra ciclos de atualização (um
/// listener de A escrevendo em B, cujo listener escreve de volta em A,
/// indefinidamente).
const int kMaxNotificationDepth = 100;

int _notificationDepth = 0;

/// Holds the set of listeners attached to a single observable and notifies
/// them safely, tolerating listeners that add/remove other listeners during
/// notification.
///
/// Mantém o conjunto de listeners de um único observável e os notifica de
/// forma segura, tolerando listeners que adicionam/removem outros listeners
/// durante a notificação.
class ListenerRegistry {
  // A LinkedHashSet gives O(1) add/remove/contains (versus a List's O(n)
  // linear scan for `contains`/`remove`), while still preserving insertion
  // order for iteration/snapshotting, and natively deduplicating listeners
  // (a `Set`'s core contract) instead of an explicit `contains` check
  // before insertion.
  //
  // Um LinkedHashSet garante add/remove/contains em O(1) (em vez do scan
  // linear O(n) de uma List para `contains`/`remove`), preservando a ordem
  // de inserção para iteração/snapshot, e deduplicando listeners
  // nativamente (contrato central de um `Set`) em vez de uma checagem
  // explícita de `contains` antes de inserir.
  final LinkedHashSet<VoidCallback> _listeners = LinkedHashSet<VoidCallback>();

  /// Number of listeners currently attached.
  ///
  /// Número de listeners atualmente anexados.
  int get length => _listeners.length;

  /// Whether there is at least one listener attached.
  ///
  /// Se há ao menos um listener anexado.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Adds [listener] if it is not already present and returns a [Disposer]
  /// that removes it.
  ///
  /// Adiciona [listener] se ele ainda não estiver presente e retorna um
  /// [Disposer] que o remove.
  Disposer add(VoidCallback listener) {
    _listeners.add(listener);
    return () => remove(listener);
  }

  /// Whether [listener] is currently registered.
  ///
  /// Se [listener] está atualmente registrado.
  bool contains(VoidCallback listener) => _listeners.contains(listener);

  /// Removes [listener] if present.
  ///
  /// Remove [listener] se presente.
  void remove(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notifies a snapshot of the current listeners, so mutations made by a
  /// listener while notifying do not affect the current notification pass
  /// (a listener that removes itself or adds another listener only affects
  /// the *next* notification, never the current one).
  ///
  /// Each listener runs inside its own `try`/`catch`: an exception thrown by
  /// one listener is reported via [FlutterError.reportError] (library
  /// `all_observer`) and does not prevent the remaining listeners of this
  /// same notification from running.
  ///
  /// A global notification-depth counter guards against update cycles (a
  /// listener of A writing to B, whose listener writes back to A, and so
  /// on): once [kMaxNotificationDepth] nested notifications are reached,
  /// this call stops recursing and reports a [FlutterError] instead of
  /// overflowing the stack.
  ///
  /// Notifica uma cópia dos listeners atuais, de forma que mutações feitas
  /// por um listener durante a notificação não afetem o ciclo em andamento
  /// (um listener que remove a si mesmo ou adiciona outro listener só afeta
  /// a *próxima* notificação, nunca a atual).
  ///
  /// Cada listener roda dentro do seu próprio `try`/`catch`: uma exceção
  /// lançada por um listener é reportada via [FlutterError.reportError]
  /// (biblioteca `all_observer`) e não impede que os demais listeners desta
  /// mesma notificação rodem.
  ///
  /// Um contador global de profundidade de notificação protege contra
  /// ciclos de atualização (um listener de A escrevendo em B, cujo listener
  /// escreve de volta em A, e assim por diante): ao atingir
  /// [kMaxNotificationDepth] notificações aninhadas, esta chamada para de
  /// recursar e reporta um [FlutterError] em vez de estourar a pilha.
  void notifyAll() {
    if (_listeners.isEmpty) {
      return;
    }
    if (_notificationDepth >= kMaxNotificationDepth) {
      final FlutterError cycleError = FlutterError(
        'all_observer: possible update cycle detected. Notification '
        'depth exceeded $kMaxNotificationDepth (a listener of one '
        'observable writes to another whose listener writes back, '
        'forever). Stopping this notification instead of overflowing '
        'the call stack. / Possível ciclo de atualização detectado: '
        'profundidade de notificação excedeu $kMaxNotificationDepth.',
      );
      ObserverLogger.caughtException(
        'possível ciclo de atualização detectado',
        cycleError,
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: cycleError,
          library: 'all_observer',
          context: ErrorDescription('while notifying observable listeners'),
        ),
      );
      return;
    }
    final List<VoidCallback> snapshot = List<VoidCallback>.of(
      _listeners,
      growable: false,
    );
    _notificationDepth++;
    try {
      for (final VoidCallback listener in snapshot) {
        try {
          listener();
        } catch (error, stackTrace) {
          ObserverLogger.caughtException(
            'exceção isolada em um listener',
            error,
          );
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'all_observer',
              context: ErrorDescription(
                'while notifying an observable listener',
              ),
            ),
          );
        }
      }
    } finally {
      _notificationDepth--;
    }
  }

  /// Enqueues this registry for notification via the two-phase batch flush,
  /// whether or not an explicit `Observable.batch()` is already active.
  ///
  /// When a batch is already active, this registry is simply added to the
  /// pending queue as before. When no explicit batch is active, a micro-batch
  /// (`BatchScope.run`) is opened on the spot — this routes every write,
  /// even a single standalone `observable.value = x`, through the same
  /// two-phase fixed-point flush: first all registries drain (plain
  /// observables and collections settle to their final values), *then* every
  /// `Computed` marked dirty recomputes, reading only fully-settled upstream
  /// values. This makes glitch-free behavior the default for all writes,
  /// not just those wrapped in an explicit `Observable.batch()`.
  ///
  /// **Fast-path:** if there are no listeners at all, returns immediately
  /// without opening the micro-batch — this keeps zero-listener writes at
  /// the same O(1) cost as before.
  ///
  /// **Wave-limit safety net:** the micro-batch relies on the `kMaxFlushWaves`
  /// guard added in v1.1.1 (T1.1). Any in-batch cycle now terminates with a
  /// descriptive `FlutterError` instead of looping forever.
  ///
  /// Enfileira este registro para notificação via o flush de batch em duas
  /// fases, esteja ou não um `Observable.batch()` explícito ativo.
  ///
  /// Quando um batch já está ativo, este registro é simplesmente adicionado
  /// à fila pendente como antes. Quando nenhum batch explícito está ativo,
  /// um micro-batch (`BatchScope.run`) é aberto na hora — isso roteia toda
  /// escrita, mesmo um `observable.value = x` avulso, pelo mesmo flush de
  /// ponto fixo em duas fases: primeiro todos os registros são drenados
  /// (observáveis e coleções simples se estabilizam nos valores finais),
  /// *depois* todo `Computed` marcado como sujo recalcula, lendo apenas
  /// valores upstream já estabilizados. Isso torna o comportamento
  /// livre de glitch o padrão para todas as escritas, não só as envoltas
  /// em `Observable.batch()` explícito.
  ///
  /// **Fast-path:** se não há nenhum listener, retorna imediatamente sem
  /// abrir o micro-batch — mantém escritas sem listeners ao custo O(1) de
  /// antes.
  ///
  /// **Rede de segurança de ondas:** o micro-batch depende do guard
  /// `kMaxFlushWaves` adicionado na v1.1.1 (T1.1). Qualquer ciclo dentro
  /// do batch agora termina com um `FlutterError` descritivo em vez de
  /// entrar em loop infinito.
  void notifyOrQueue() {
    if (BatchScope.isActive) {
      BatchScope.queue(this);
      return;
    }
    // Fast-path: no listeners → nothing to do, skip the micro-batch overhead.
    // Caminho rápido: sem listeners → nada a fazer, evita o overhead do
    // micro-batch.
    if (!hasListeners) {
      return;
    }
    // Wrap in a micro-batch so that even a single standalone write goes
    // through the two-phase flush: registries first, Computeds second.
    // Envolve em um micro-batch para que mesmo uma escrita avulsa passe
    // pelo flush em duas fases: registros primeiro, Computeds depois.
    BatchScope.run(() => BatchScope.queue(this));
  }

  /// Removes every listener. Called on dispose.
  ///
  /// Remove todos os listeners. Chamado no dispose.
  void clear() {
    _listeners.clear();
  }
}
