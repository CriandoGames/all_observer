import '../engine/reactive_engine.dart';
import '../logging/observer_config.dart';
import '../protocol/observer_protocol.dart';
import '../protocol/observer_protocol_event.dart';
import 'engine_bridge.dart';
import 'listener_registry.dart';
import 'observer_inspector.dart';
import 'typedefs.dart';

/// A single frame of the tracking stack, created while an [Observer] (or
/// similar consumer) runs its builder.
///
/// Um quadro da pilha de rastreamento, criado enquanto um [Observer] (ou
/// consumidor similar) executa seu builder.
///
/// A protocol-enabled context also collects stable dependency IDs. Existing
/// listeners/disposers remain the source of truth for reactive behavior.
///
/// Um contexto com protocolo também coleta IDs estáveis. Os listeners e
/// disposers existentes continuam sendo a fonte de verdade reativa.
class TrackingContext {
  /// Creates a tracking context that reports dependency changes to
  /// [onDependencyChanged]. [ownerLabel], if given, identifies the
  /// Observer/Computed/Effect doing the tracking, for
  /// `ObserverInspector.onTrack` events.
  ///
  /// Cria um contexto de rastreamento que reporta mudanças de dependência
  /// para [onDependencyChanged]. [ownerLabel], se fornecido, identifica o
  /// Observer/Computed/Effect que está rastreando, para eventos
  /// `ObserverInspector.onTrack`.
  TrackingContext(
    this.onDependencyChanged, {
    this.ownerLabel,
    this.subscribes = true,
    this.onTrackedWrite,
    this.onDependencyChangedFrom,
    this.protocolTracker,
  });

  /// Invoked when any observable read during this context later changes.
  ///
  /// Invocado quando qualquer observável lido durante este contexto mudar
  /// posteriormente.
  final ObserverVoidCallback onDependencyChanged;

  /// Optional dependency-aware variant of [onDependencyChanged]. Effects use
  /// this to distinguish direct self-invalidations from unrelated
  /// invalidations that happen during the same flush.
  ///
  /// Variante opcional de [onDependencyChanged] que informa a dependÃªncia.
  /// Effects usam isso para diferenciar auto-invalidaÃ§Ãµes diretas de
  /// invalidaÃ§Ãµes nÃ£o relacionadas no mesmo flush.
  final void Function(ListenerRegistry registry)? onDependencyChangedFrom;

  /// Whether reads inside this context subscribe [onDependencyChanged] to
  /// each read registry (the classic Observer/effect behavior). A
  /// recomputing `CoreComputed` (engine v2) pushes a non-subscribing
  /// context: it still isolates outer contexts, counts reads and emits
  /// `onTrack` events, but invalidation is handled by the engine graph, so
  /// no registry listeners are registered (and none need disposal).
  ///
  /// Se leituras dentro deste contexto inscrevem [onDependencyChanged] em
  /// cada registry lido (o comportamento clássico de Observer/effect). Um
  /// `CoreComputed` recomputando (motor v2) empilha um contexto
  /// não-inscritor: ele ainda isola contextos externos, conta leituras e
  /// emite eventos `onTrack`, mas a invalidação é tratada pelo grafo do
  /// motor, então nenhum listener de registry é registrado (e nenhum
  /// precisa de descarte).
  final bool subscribes;

  /// Optional hook invoked when code writes to a [CoreObservable] while this
  /// context is active. Effects use it to recognize self-invalidations caused
  /// by their own body during a batch flush.
  ///
  /// Gancho opcional chamado quando um código escreve em um [CoreObservable]
  /// enquanto este contexto está ativo. Effects usam isso para reconhecer
  /// auto-invalidações causadas pelo próprio corpo durante um flush de batch.
  final void Function(ListenerRegistry registry)? onTrackedWrite;

  /// Debug label of the Observer/Computed/Effect that owns this context, if
  /// known. Only used to populate `ObserverInspector.onTrack` events — has
  /// no effect on tracking behavior itself.
  ///
  /// Rótulo de debug do Observer/Computed/Effect dono deste contexto, se
  /// conhecido. Usado apenas para popular eventos
  /// `ObserverInspector.onTrack` — não tem efeito no comportamento de
  /// rastreamento em si.
  final String? ownerLabel;

  /// Optional Observer Protocol identity for this tracked owner.
  ///
  /// Identidade opcional do Observer Protocol para este dono rastreado.
  final ObserverProtocolTracker? protocolTracker;

  /// Stable dependency IDs read during this run. It is allocated only while
  /// the protocol is enabled.
  ///
  /// IDs estáveis lidos nesta execução. Alocado apenas com protocolo ativo.
  final Set<ObserverNodeId>? protocolDependencyIds = ObserverProtocol.isEnabled
      ? <ObserverNodeId>{}
      : null;

  /// Disposers accumulated for every distinct observable read while this
  /// context was active. Executed on unmount / next build.
  ///
  /// Disposers acumulados para cada observável distinto lido enquanto este
  /// contexto estava ativo. Executados no unmount / próximo build.
  final List<Disposer> disposers = <Disposer>[];

  /// Number of distinct observables read during this context. Used to warn
  /// about builders that read nothing.
  ///
  /// Número de observáveis distintos lidos durante este contexto. Usado
  /// para alertar sobre builders que não leem nada.
  int readCount = 0;

  /// Debug-only labels of the distinct observables read during this
  /// context, in read order. Used for the Observer tracking log.
  ///
  /// Rótulos (debug) dos observáveis distintos lidos durante este
  /// contexto, na ordem de leitura. Usado no log de rastreamento do
  /// Observer.
  final List<String> trackedLabels = <String>[];

  /// Debug-only registry of already-tracked listeners, avoiding duplicate
  /// disposers when the same observable is read multiple times.
  ///
  /// Registro (debug) dos listeners já rastreados, evitando disposers
  /// duplicados quando o mesmo observável é lido múltiplas vezes.
  final Set<ListenerRegistry> _seen = <ListenerRegistry>{};

  bool _hasSeen(ListenerRegistry registry) => !_seen.add(registry);
}

/// Reentrant stack-based dependency tracker.
///
/// Replaces a single mutable "current context" with a stack so that nested
/// tracking (e.g. an [Observer] built inside another [Observer]) restores
/// the outer context correctly once the inner one finishes.
///
/// Rastreador de dependências reentrante, baseado em pilha.
///
/// Substitui um único "contexto atual" mutável por uma pilha, de forma que
/// o rastreamento aninhado (ex.: um [Observer] construído dentro de outro)
/// restaure corretamente o contexto externo quando o interno terminar.
abstract final class DependencyTracker {
  static final List<TrackingContext> _stack = <TrackingContext>[];

  /// Nesting depth of active [untracked] calls. While greater than zero,
  /// [current] reports `null` regardless of [_stack], so any observable read
  /// underneath is not registered as a dependency of whatever outer context
  /// (if any) is still on the stack.
  ///
  /// Profundidade de aninhamento de chamadas [untracked] ativas. Enquanto
  /// maior que zero, [current] reporta `null` independentemente de [_stack],
  /// então qualquer leitura de observável feita por baixo não é registrada
  /// como dependência de qualquer contexto externo (se houver) ainda
  /// empilhado.
  static int _suspendDepth = 0;

  /// The innermost active tracking context, or `null` if none is active, or
  /// if an [untracked] call is currently suspending tracking.
  ///
  /// O contexto de rastreamento ativo mais interno, ou `null` se nenhum
  /// estiver ativo, ou se uma chamada [untracked] estiver atualmente
  /// suspendendo o rastreamento.
  static TrackingContext? get current {
    if (_suspendDepth > 0) {
      return null;
    }
    return _stack.isEmpty ? null : _stack.last;
  }

  /// Runs [action] with dependency tracking suspended: any observable read
  /// inside [action] is *not* registered as a dependency of whatever
  /// [Observer]/[Computed]/effect is currently tracking, even though that
  /// outer context remains active underneath. Supports nesting (only the
  /// outermost call needs to restore suspension). Powers the top-level
  /// `untracked()` function and `Observable.peek()`.
  ///
  /// Executa [action] com o rastreamento de dependências suspenso: qualquer
  /// observável lido dentro de [action] *não* é registrado como dependência
  /// do [Observer]/[Computed]/effect que estiver rastreando no momento,
  /// mesmo que esse contexto externo continue ativo por baixo. Suporta
  /// aninhamento (apenas a chamada mais externa precisa restaurar a
  /// suspensão). Alimenta a função `untracked()` de nível superior e
  /// `Observable.peek()`.
  static R untracked<R>(R Function() action) {
    _suspendDepth++;
    try {
      return action();
    } finally {
      _suspendDepth--;
    }
  }

  /// Runs [action] with [context] pushed onto the tracking stack, popping
  /// it afterwards even if [action] throws.
  ///
  /// In debug mode, a top-level call (one that starts with an empty stack)
  /// asserts that the stack is empty again once popped back to depth zero.
  /// This is a leak canary: static/global state must never retain a
  /// [TrackingContext] tied to an unmounted [Element] or [BuildContext]
  /// across frames — if it did, this assertion would fail the next time a
  /// top-level track runs.
  ///
  /// Executa [action] com [context] empilhado no rastreador, desempilhando
  /// mesmo se [action] lançar uma exceção.
  ///
  /// Em modo debug, uma chamada de nível superior (que começa com a pilha
  /// vazia) garante, via `assert`, que a pilha volte a ficar vazia após ser
  /// desempilhada até a profundidade zero. Isso funciona como um canário de
  /// vazamento: estado estático/global nunca deve reter um [TrackingContext]
  /// vinculado a um [Element] ou [BuildContext] desmontado entre frames —
  /// se isso ocorresse, esta asserção falharia na próxima chamada de
  /// rastreamento de nível superior.
  static R track<R>(TrackingContext context, R Function() action) {
    final bool isTopLevel = _stack.isEmpty;
    final ObserverProtocolRun? protocolRun = context.protocolTracker == null
        ? null
        : ObserverProtocol.beginTrackerRun(context.protocolTracker!);
    var completedWithError = false;
    _stack.add(context);
    try {
      return action();
    } catch (_) {
      completedWithError = true;
      rethrow;
    } finally {
      _stack.removeLast();
      if (protocolRun != null) {
        ObserverProtocol.finishTrackerRun(
          protocolRun,
          dependencyIds:
              context.protocolDependencyIds ?? const <ObserverNodeId>{},
          completedWithError: completedWithError,
        );
      }
      if (isTopLevel) {
        assert(
          _stack.isEmpty,
          'DependencyTracker leaked a TrackingContext: the stack should be '
          'empty after a top-level track() call returns.',
        );
      }
    }
  }

  /// Called from an observable's `value` getter to register the current
  /// tracking context's own [TrackingContext.onDependencyChanged] callback
  /// (if any context is active) as a listener of [registry]. The context,
  /// not the observable, owns the callback that must run when [registry]
  /// notifies — an observable must never register itself as its own
  /// listener.
  ///
  /// Chamado a partir do getter `value` de um observável para registrar o
  /// callback [TrackingContext.onDependencyChanged] do contexto de
  /// rastreamento atual (se houver algum ativo) como listener de
  /// [registry]. É o contexto, não o observável, que possui o callback a
  /// ser executado quando [registry] notificar — um observável nunca deve
  /// se registrar como seu próprio listener.
  static void reportRead(ListenerRegistry registry, {String? label}) {
    if (_suspendDepth > 0) {
      return; // untracked(): no context AND no engine link / sem link no motor
    }
    // Engine path (engine v2): while a CoreComputed is recomputing, every
    // read links this registry's engine node as a dependency of it. The
    // node is created lazily, so registries never read inside a computed
    // pay nothing.
    //
    // Caminho do motor (motor v2): enquanto um CoreComputed recomputa, cada
    // leitura liga o nó de motor deste registry como dependência dele. O nó
    // é criado preguiçosamente, então registries nunca lidos dentro de um
    // computed não pagam nada.
    final ObserverEngine engine = ObserverEngine.instance;
    final ReactiveNode? engineSub = engine.activeSub;
    if (engineSub != null) {
      engine.link(
        registry.engineNode ??= RegistrySignalNode(),
        engineSub,
        engine.cycle,
      );
    }
    final TrackingContext? context = current;
    if (context == null) {
      return;
    }
    context.readCount++;
    final ObserverNodeId? protocolNodeId = registry.protocolNodeId;
    if (protocolNodeId != null) {
      context.protocolDependencyIds?.add(protocolNodeId);
    }
    if (context._hasSeen(registry)) {
      return;
    }
    if (context.subscribes) {
      final ObserverVoidCallback listener =
          context.onDependencyChangedFrom == null
          ? context.onDependencyChanged
          : () => context.onDependencyChangedFrom!(registry);
      final Disposer disposer = registry.add(listener);
      context.disposers.add(disposer);
    }
    if (label != null) {
      context.trackedLabels.add(label);
      if (context.ownerLabel != null) {
        dispatchToInspectors(
          ObserverConfig.inspectors,
          (ObserverInspector i) => i.onTrack(
            TrackEvent(
              context.ownerLabel!,
              label,
              stackTrace: ObserverConfig.captureStackTraces
                  ? StackTrace.current
                  : null,
            ),
          ),
        );
      }
    }
  }
}
