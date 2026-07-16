import 'dart:collection' show LinkedHashSet;

import '../engine/reactive_engine.dart';
import '../errors/observer_cycle_error.dart';
import 'batch_scope.dart';
import 'core_error_reporting.dart';
import 'engine_bridge.dart';
import 'typedefs.dart';

// Note: this file intentionally does not import `dart:ui` or
// `package:flutter/foundation.dart` for `ObserverVoidCallback` — `dart:ui` is part
// of the Flutter *engine* embedding, not the plain Dart SDK, so it is not
// available in a CLI/server context. `ObserverObserverVoidCallback` (from
// typedefs.dart) is a structurally identical `void Function()` alias that
// keeps this file usable from `package:all_observer/core.dart` alone.

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
  /// Creates an empty listener registry.
  ///
  /// Cria um registro de listeners vazio.
  ListenerRegistry();

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
  final LinkedHashSet<ObserverVoidCallback> _listeners =
      LinkedHashSet<ObserverVoidCallback>();

  /// The engine-graph identity of this registry, if any (engine v2).
  ///
  /// Lazily assigned by `DependencyTracker.reportRead` (a
  /// [RegistrySignalNode]) the first time this registry is read inside a
  /// recomputing `CoreComputed`, or pre-assigned by `CoreComputed` itself
  /// (its [ComputedEngineNode]) so that reads of a computed link to the
  /// computed's own node. `null` until then — registries never read inside
  /// a computed pay zero engine cost.
  ///
  /// A identidade deste registry no grafo do motor, se houver (motor v2).
  ///
  /// Atribuído preguiçosamente por `DependencyTracker.reportRead` (um
  /// [RegistrySignalNode]) na primeira vez que este registry é lido dentro
  /// de um `CoreComputed` recomputando, ou pré-atribuído pelo próprio
  /// `CoreComputed` (seu [ComputedEngineNode]) para que leituras de um
  /// computed liguem ao nó do próprio computed. `null` até lá — registries
  /// nunca lidos dentro de um computed pagam custo zero de motor.
  ReactiveNode? engineNode;

  /// Number of listeners currently attached.
  ///
  /// Número de listeners atualmente anexados.
  int get length => _listeners.length;

  /// Whether there is at least one interested party attached — a plain
  /// listener, or (engine v2) a `CoreComputed` depending on this registry
  /// through the engine graph. Before the engine, computeds subscribed
  /// here as regular listeners, so counting engine dependents preserves
  /// the long-standing meaning of `Observable.hasListeners` (e.g. "did the
  /// computed unsubscribe from the dropped branch / on close?").
  ///
  /// Se há ao menos um interessado anexado — um listener comum, ou (motor
  /// v2) um `CoreComputed` dependendo deste registry pelo grafo do motor.
  /// Antes do motor, computeds se inscreviam aqui como listeners comuns,
  /// então contar os dependentes do motor preserva o significado de longa
  /// data de `Observable.hasListeners` (ex.: "o computed se desinscreveu
  /// do branch abandonado / no close?").
  bool get hasListeners => _listeners.isNotEmpty || hasEngineSubscribers;

  /// Whether any engine-graph subscriber is currently linked to this
  /// registry's [RegistrySignalNode]. `false` for registries that were
  /// never read inside a computed (no engine node exists) and for a
  /// computed's own registry (whose node is a `ComputedEngineNode` — its
  /// dependents are tracked by the computed itself).
  ///
  /// Se algum subscriber do grafo do motor está atualmente ligado ao
  /// [RegistrySignalNode] deste registry. `false` para registries nunca
  /// lidos dentro de um computed (nenhum nó do motor existe) e para o
  /// registry do próprio computed (cujo nó é um `ComputedEngineNode` — os
  /// dependentes dele são rastreados pelo próprio computed).
  bool get hasEngineSubscribers {
    final ReactiveNode? node = engineNode;
    return node is RegistrySignalNode && node.subs != null;
  }

  /// Adds [listener] if it is not already present and returns a [Disposer]
  /// that removes it.
  ///
  /// Adiciona [listener] se ele ainda não estiver presente e retorna um
  /// [Disposer] que o remove.
  Disposer add(ObserverVoidCallback listener) {
    _listeners.add(listener);
    return () => remove(listener);
  }

  /// Whether [listener] is currently registered.
  ///
  /// Se [listener] está atualmente registrado.
  bool contains(ObserverVoidCallback listener) => _listeners.contains(listener);

  /// Removes [listener] if present.
  ///
  /// Remove [listener] se presente.
  void remove(ObserverVoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notifies a snapshot of the current listeners, so mutations made by a
  /// listener while notifying do not affect the current notification pass
  /// (a listener that removes itself or adds another listener only affects
  /// the *next* notification, never the current one).
  ///
  /// Each listener runs inside its own `try`/`catch`: an exception thrown by
  /// one listener is reported via `CoreErrorReporting.report` (library
  /// `all_observer`) and does not prevent the remaining listeners of this
  /// same notification from running.
  ///
  /// A global notification-depth counter guards against update cycles (a
  /// listener of A writing to B, whose listener writes back to A, and so
  /// on): once [kMaxNotificationDepth] nested notifications are reached,
  /// this call stops recursing and reports an [ObserverCycleError] instead of
  /// overflowing the stack.
  ///
  /// Notifica uma cópia dos listeners atuais, de forma que mutações feitas
  /// por um listener durante a notificação não afetem o ciclo em andamento
  /// (um listener que remove a si mesmo ou adiciona outro listener só afeta
  /// a *próxima* notificação, nunca a atual).
  ///
  /// Cada listener roda dentro do seu próprio `try`/`catch`: uma exceção
  /// lançada por um listener é reportada via `CoreErrorReporting.report`
  /// (biblioteca `all_observer`) e não impede que os demais listeners desta
  /// mesma notificação rodem.
  ///
  /// Um contador global de profundidade de notificação protege contra
  /// ciclos de atualização (um listener de A escrevendo em B, cujo listener
  /// escreve de volta em A, e assim por diante): ao atingir
  /// [kMaxNotificationDepth] notificações aninhadas, esta chamada para de
  /// recursar e reporta um [ObserverCycleError] em vez de estourar a pilha.
  void notifyAll() {
    // Engine push (engine v2): if any CoreComputed depends on this registry
    // through the engine graph, mark the change and propagate staleness
    // flags now — at delivery time, so in-batch reads stayed stale until
    // this moment. Watching nodes get scheduled into the current flush's
    // phase 2 (`BatchScope.queueDirtyFlush`), where deferred recomputes
    // always ran. Only [RegistrySignalNode]s propagate here — a computed's
    // own registry carries a [ComputedEngineNode], whose engine propagation
    // is handled by the computed itself when it recomputes.
    //
    // Push do motor (motor v2): se algum CoreComputed depende deste
    // registry pelo grafo do motor, marca a mudança e propaga as flags de
    // obsolescência agora — no momento da entrega, então leituras dentro do
    // batch permaneceram obsoletas até este instante. Nós watching são
    // agendados na fase 2 do flush atual (`BatchScope.queueDirtyFlush`),
    // onde os recomputes adiados sempre rodaram. Só [RegistrySignalNode]s
    // propagam aqui — o registry de um computed carrega um
    // [ComputedEngineNode], cuja propagação no motor é feita pelo próprio
    // computed ao recomputar.
    final ReactiveNode? engineNode = this.engineNode;
    if (engineNode is RegistrySignalNode) {
      final ReactiveLink? engineSubs = engineNode.subs;
      if (engineSubs != null) {
        engineNode.flags = ReactiveFlags.mutableDirty;
        ObserverEngine.instance.propagate(engineSubs);
      }
    }
    if (_listeners.isEmpty) {
      return;
    }
    if (_notificationDepth >= kMaxNotificationDepth) {
      final ObserverCycleError cycleError = ObserverCycleError(
        'all_observer: possible update cycle detected. Notification '
        'depth exceeded $kMaxNotificationDepth (a listener of one '
        'observable writes to another whose listener writes back, '
        'forever). Stopping this notification instead of overflowing '
        'the call stack. / Possível ciclo de atualização detectado: '
        'profundidade de notificação excedeu $kMaxNotificationDepth.',
      );
      CoreErrorReporting.report(
        cycleError,
        StackTrace.current,
        library: 'all_observer',
        context:
            'possível ciclo de atualização detectado — while '
            'notifying observable listeners',
      );
      return;
    }
    final List<ObserverVoidCallback> snapshot = List<ObserverVoidCallback>.of(
      _listeners,
      growable: false,
    );
    _notificationDepth++;
    try {
      for (final ObserverVoidCallback listener in snapshot) {
        try {
          listener();
        } catch (error, stackTrace) {
          CoreErrorReporting.report(
            error,
            stackTrace,
            library: 'all_observer',
            context:
                'exceção isolada em um listener — while notifying an '
                'observable listener',
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
  /// descriptive `ObserverCycleError` instead of looping forever.
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
  /// do batch agora termina com um `ObserverCycleError` descritivo em vez de
  /// entrar em loop infinito.
  void notifyOrQueue() {
    if (BatchScope.isActive) {
      BatchScope.queue(this);
      return;
    }
    // Fast-path: no listeners and no engine subscribers → nothing to do,
    // skip the micro-batch overhead. Engine staleness marking (engine v2)
    // happens inside [notifyAll], i.e. only when the flush actually
    // delivers this notification — so a Computed read while a batch is
    // still open keeps seeing the pre-batch value, exactly like any other
    // deferred notification.
    //
    // Caminho rápido: sem listeners e sem subscribers no motor → nada a
    // fazer, evita o overhead do micro-batch. A marcação de obsolescência
    // do motor (motor v2) acontece dentro de [notifyAll], isto é, apenas
    // quando o flush de fato entrega esta notificação — assim um Computed
    // lido com um batch ainda aberto continua vendo o valor pré-batch,
    // exatamente como qualquer outra notificação adiada.
    if (!hasListeners) {
      return; // [hasListeners] already counts engine subscribers / já conta
      //          os subscribers do motor
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
