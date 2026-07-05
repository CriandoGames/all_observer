import 'listener_registry.dart';
import 'typedefs.dart';

/// A single frame of the tracking stack, created while an [Observer] (or
/// similar consumer) runs its builder.
///
/// Um quadro da pilha de rastreamento, criado enquanto um [Observer] (ou
/// consumidor similar) executa seu builder.
class TrackingContext {
  /// Creates a tracking context that reports dependency changes to
  /// [onDependencyChanged].
  ///
  /// Cria um contexto de rastreamento que reporta mudanças de dependência
  /// para [onDependencyChanged].
  TrackingContext(this.onDependencyChanged);

  /// Invoked when any observable read during this context later changes.
  ///
  /// Invocado quando qualquer observável lido durante este contexto mudar
  /// posteriormente.
  final ObserverVoidCallback onDependencyChanged;

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
    _stack.add(context);
    try {
      return action();
    } finally {
      _stack.removeLast();
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
    final TrackingContext? context = current;
    if (context == null) {
      return;
    }
    context.readCount++;
    if (context._hasSeen(registry)) {
      return;
    }
    final Disposer disposer = registry.add(context.onDependencyChanged);
    context.disposers.add(disposer);
    if (label != null) {
      context.trackedLabels.add(label);
    }
  }
}
