import 'core_error_reporting.dart';
import 'observer_inspector.dart';
import 'typedefs.dart';
import '../errors/observer_error.dart';
import '../logging/observer_config.dart';
import '../protocol/observer_protocol.dart';
import '../protocol/observer_protocol_event.dart';

/// An ambient disposal scope: every `Computed`/`CoreComputed`, `effect()`
/// and worker (`ever`, `once`, `debounce`, `interval`) created inside
/// [run] registers its own disposer here automatically, so a single call
/// to [dispose] tears all of them down at once — no hand-rolled list of
/// disposers, no forgotten `close()`.
///
/// ```dart
/// final scope = ReactiveScope(name: 'CounterController');
///
/// scope.run(() {
///   total = Computed(() => a.value + b.value); // registered in the scope
///   effect(() => print(total.value));          // registered in the scope
///   ever(a, (_) => save());                    // registered in the scope
/// });
///
/// scope.dispose(); // closes the Computed, cancels the effect and worker
/// ```
///
/// Opt-in by design: creating a `Computed`/`effect`/worker *outside* any
/// [run] call behaves exactly as before this class existed — nothing is
/// registered anywhere, and the caller stays responsible for disposal.
///
/// Plain `Observable`s are deliberately **not** registered in a scope:
/// today an `Observable` holds no resource that must be released — its
/// `close()` only clears listeners, and listeners are owned (and disposed)
/// by their consumers (`Observer`/`Computed`/`effect`/workers), not by the
/// observable itself. The same applies to `Observable` subclasses
/// (`ObservableFuture`, `ObservableStream`, the reactive collections):
/// register those manually via [add] (e.g. `scope.add(future.close)`) when
/// you want a scope to own them.
///
/// Nesting: a [ReactiveScope] *constructed* while another scope is active
/// (i.e. inside the parent's [run]) registers its own [dispose] in that
/// parent, so disposing the parent also disposes the child. Disposing the
/// child first never affects the parent — [dispose] is idempotent, so the
/// parent later re-invoking it is a no-op.
///
/// Interaction with `Observable.batch()`: none, by design. The scope only
/// captures *creation* of reactive resources; batching only coalesces
/// *notifications*. Creating resources inside a batch inside a scope (or
/// vice versa) works with no special rules.
///
/// Um escopo de descarte ambiente: todo `Computed`/`CoreComputed`,
/// `effect()` e worker (`ever`, `once`, `debounce`, `interval`) criado
/// dentro de [run] registra seu próprio disposer aqui automaticamente, de
/// forma que uma única chamada a [dispose] derruba todos de uma vez — sem
/// lista de disposers feita à mão, sem `close()` esquecido.
///
/// Opt-in por design: criar um `Computed`/`effect`/worker *fora* de
/// qualquer chamada a [run] se comporta exatamente como antes desta classe
/// existir — nada é registrado em lugar nenhum, e quem chama continua
/// responsável pelo descarte.
///
/// `Observable`s simples deliberadamente **não** são registrados em um
/// escopo: hoje um `Observable` não possui recurso que precise ser
/// liberado — seu `close()` apenas limpa listeners, e listeners pertencem
/// (e são descartados) pelos seus consumidores
/// (`Observer`/`Computed`/`effect`/workers), não pelo próprio observável.
/// O mesmo vale para subclasses de `Observable` (`ObservableFuture`,
/// `ObservableStream`, as coleções reativas): registre-as manualmente via
/// [add] (ex.: `scope.add(future.close)`) quando quiser que um escopo seja
/// dono delas.
///
/// Aninhamento: um [ReactiveScope] *construído* enquanto outro escopo está
/// ativo (isto é, dentro do [run] do pai) registra seu próprio [dispose]
/// naquele pai, então descartar o pai também descarta o filho. Descartar o
/// filho primeiro nunca afeta o pai — [dispose] é idempotente, então o pai
/// invocá-lo de novo depois é um no-op.
///
/// Interação com `Observable.batch()`: nenhuma, por design. O escopo só
/// captura a *criação* de recursos reativos; o batch só agrupa
/// *notificações*. Criar recursos dentro de um batch dentro de um escopo
/// (ou vice-versa) funciona sem regras especiais.
///
/// Observer Protocol assigns stable IDs to the scope and its resources. The
/// debug registry stores metadata only; it does not add disposer retention.
///
/// O Observer Protocol atribui IDs estáveis ao escopo e seus recursos. O
/// registry armazena apenas metadados, sem retenção adicional de disposers.
class ReactiveScope {
  /// Creates a scope. An optional [name] is used in logs and inspector
  /// events; when omitted, a short hash-based label is used instead.
  ///
  /// If another scope is currently active (this constructor ran inside its
  /// [run]), this scope registers its own [dispose] in that parent — see
  /// the class doc's nesting note.
  ///
  /// Cria um escopo. Um [name] opcional é usado em logs e eventos de
  /// inspector; quando omitido, um rótulo curto baseado no hash é usado.
  ///
  /// Se outro escopo estiver ativo no momento (este construtor rodou
  /// dentro do [run] dele), este escopo registra seu próprio [dispose]
  /// naquele pai — ver a nota sobre aninhamento no doc da classe.
  ReactiveScope({this.name}) {
    ObserverProtocol.nodeCreated(
      objectId: objectId,
      kind: ObserverNodeKind.scope,
      debugLabel: label,
      debugType: runtimeType.toString(),
    );
    ObserverProtocol.scopeCreated(scopeId: objectId, debugLabel: label);
    current?.add(
      dispose,
      resourceId: objectId,
      resourceKind: ObserverNodeKind.scope,
    );
  }

  /// Optional debug label shown in logs and inspector events.
  ///
  /// Rótulo de debug opcional exibido em logs e eventos de inspector.
  final String? name;

  /// Stable identity used by Observer Protocol scope events and snapshots.
  ///
  /// Identidade estável usada nos eventos e snapshots de escopo.
  final ObserverNodeId objectId = ObserverProtocol.allocateNodeId();

  /// Alias for [objectId] emphasizing this node's scope role.
  ///
  /// Alias de [objectId] que enfatiza o papel de escopo deste nó.
  ObserverNodeId get scopeId => objectId;

  // Same stack-based ambient pattern as `DependencyTracker`: `run` pushes,
  // executes, pops in `finally`, so nested `run` calls restore the outer
  // scope correctly and an exception never leaves a stale scope active.
  //
  // Mesmo padrão ambiente baseado em pilha do `DependencyTracker`: `run`
  // empilha, executa, desempilha em `finally`, então chamadas aninhadas a
  // `run` restauram o escopo externo corretamente e uma exceção nunca
  // deixa um escopo obsoleto ativo.
  static final List<ReactiveScope> _stack = <ReactiveScope>[];

  /// The innermost scope currently executing a [run] call, or `null` if
  /// none. This is the registration target `CoreComputed`, `effect()` and
  /// the workers consult on creation.
  ///
  /// O escopo mais interno atualmente executando uma chamada a [run], ou
  /// `null` se nenhum. Este é o alvo de registro que `CoreComputed`,
  /// `effect()` e os workers consultam na criação.
  static ReactiveScope? get current => _stack.isEmpty ? null : _stack.last;

  final List<Disposer> _disposers = <Disposer>[];
  bool _isDisposed = false;

  /// Whether [dispose] has already been called.
  ///
  /// Se [dispose] já foi chamado.
  bool get isDisposed => _isDisposed;

  /// Debug label used in logs and inspector events: [name], if given,
  /// otherwise a short hash-based fallback.
  ///
  /// Rótulo de debug usado em logs e eventos de inspector: [name], se
  /// fornecido, senão um fallback curto baseado no hash.
  String get label => 'ReactiveScope(${name ?? '#$hashCode'})';

  /// Runs [fn] with this scope active: every `Computed`/`effect`/worker
  /// created inside [fn] registers its disposer here. Supports nesting
  /// (the previous active scope is restored afterwards, even if [fn]
  /// throws) and may be called multiple times on the same scope — later
  /// registrations simply accumulate.
  ///
  /// Executa [fn] com este escopo ativo: todo `Computed`/`effect`/worker
  /// criado dentro de [fn] registra seu disposer aqui. Suporta aninhamento
  /// (o escopo ativo anterior é restaurado depois, mesmo se [fn] lançar) e
  /// pode ser chamado múltiplas vezes no mesmo escopo — registros
  /// posteriores simplesmente se acumulam.
  R run<R>(R Function() fn) {
    _stack.add(this);
    try {
      return fn();
    } finally {
      _stack.removeLast();
    }
  }

  /// Manually registers [disposer] to be called by [dispose]. This is the
  /// same entry point `CoreComputed`/`effect()`/workers use internally;
  /// use it directly for resources the scope does not capture on its own
  /// (an `ObservableSubscription.cancel`, an `ObservableFuture.close`, a
  /// `StreamSubscription.cancel` tear-off wrapped in a closure, ...).
  ///
  /// Registering on an already-disposed scope is a programming error:
  /// [disposer] runs immediately (so the resource is never leaked), a
  /// warning is dispatched to `ObserverConfig.inspectors`, and an
  /// [ObserverError] is thrown if `ObserverConfig.strictMode` is enabled —
  /// the same misuse pattern as writing to a closed observable.
  ///
  /// Registra manualmente [disposer] para ser chamado por [dispose]. Este
  /// é o mesmo ponto de entrada que `CoreComputed`/`effect()`/workers usam
  /// internamente; use-o diretamente para recursos que o escopo não
  /// captura sozinho (um `ObservableSubscription.cancel`, um
  /// `ObservableFuture.close`, um tear-off de `StreamSubscription.cancel`
  /// envolvido em uma closure, ...).
  ///
  /// Registrar em um escopo já descartado é um erro de programação:
  /// [disposer] roda imediatamente (para o recurso nunca vazar), um
  /// warning é despachado para `ObserverConfig.inspectors`, e um
  /// [ObserverError] é lançado se `ObserverConfig.strictMode` estiver
  /// habilitado — o mesmo padrão de mau uso de escrever em um observável
  /// fechado.
  void add(
    Disposer disposer, {
    ObserverNodeId? resourceId,
    ObserverNodeKind resourceKind = ObserverNodeKind.subscription,
  }) {
    if (_isDisposed) {
      // Dispose first, then (maybe) throw: even under strictMode the
      // resource must never leak.
      //
      // Descarta primeiro, depois (talvez) lança: mesmo sob strictMode o
      // recurso nunca pode vazar.
      disposer();
      final String message =
          'Tentativa de registrar um recurso em $label já descartado. O '
          'recurso foi descartado imediatamente.';
      if (ObserverConfig.strictMode) {
        throw ObserverError(message);
      }
      _warn(
        message,
        suggestion:
            'Nada deveria criar recursos reativos em um escopo morto. O '
            'dispose() rodou cedo demais, ou este registro tarde demais?',
      );
      return;
    }
    _disposers.add(disposer);
    if (ObserverProtocol.isEnabled) {
      ObserverProtocol.scopeResourceRegistered(
        scopeId: objectId,
        resourceId: resourceId ?? ObserverProtocol.allocateNodeId(),
        resourceKind: resourceKind,
      );
    }
  }

  /// Disposes everything registered in this scope, in reverse registration
  /// (LIFO) order — resources created last are torn down first, so a
  /// late-created `effect` that reads an earlier-created `Computed` is
  /// canceled before that `Computed` closes. Idempotent: the second and
  /// subsequent calls are no-ops. An exception thrown by one disposer is
  /// reported (via `CoreErrorReporting.report`, library `all_observer`)
  /// and never prevents the remaining disposers from running.
  ///
  /// Dispatches an `ObserverInspector.onScopeDispose` event with this
  /// scope's [label] and how many disposers ran.
  ///
  /// Descarta tudo que foi registrado neste escopo, em ordem inversa de
  /// registro (LIFO) — recursos criados por último são derrubados
  /// primeiro, então um `effect` criado depois, que lê um `Computed`
  /// criado antes, é cancelado antes daquele `Computed` fechar.
  /// Idempotente: a segunda chamada em diante é um no-op. Uma exceção
  /// lançada por um disposer é reportada (via `CoreErrorReporting.report`,
  /// biblioteca `all_observer`) e nunca impede os demais disposers de
  /// rodarem.
  ///
  /// Despacha um evento `ObserverInspector.onScopeDispose` com o [label]
  /// deste escopo e quantos disposers rodaram.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _isDisposed = true;
    // Snapshot + clear before running, so a disposer that (incorrectly)
    // triggers new registrations only ever hits the already-disposed path
    // in [add], never mutates the list being iterated.
    //
    // Snapshot + clear antes de rodar, para que um disposer que
    // (incorretamente) dispare novos registros só atinja o caminho de
    // já-descartado em [add], nunca mute a lista sendo iterada.
    final List<Disposer> disposers = List<Disposer>.of(_disposers);
    _disposers.clear();
    var failedDisposeCount = 0;
    for (final Disposer disposer in disposers.reversed) {
      try {
        disposer();
      } catch (error, stackTrace) {
        failedDisposeCount++;
        CoreErrorReporting.report(
          error,
          stackTrace,
          library: 'all_observer',
          context:
              'exceção isolada em um disposer de $label — while '
              'disposing a ReactiveScope',
        );
      }
    }
    ObserverProtocol.scopeDisposed(
      scopeId: objectId,
      registeredResourceCount: disposers.length,
      disposedResourceCount: disposers.length - failedDisposeCount,
      failedDisposeCount: failedDisposeCount,
    );
    ObserverProtocol.nodeDisposed(
      objectId: objectId,
      kind: ObserverNodeKind.scope,
    );
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onScopeDispose(
        ScopeDisposeEvent(
          label,
          disposers.length,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
  }

  // Mirrors CoreObservable._warn: in this pure-Dart core there is no
  // `ObserverLogger`/`kDebugMode` (both Flutter-side), so misuse warnings
  // are dispatched as `WarningEvent`s to `ObserverConfig.inspectors` —
  // register a `ConsoleInspector` to see them printed.
  //
  // Espelha CoreObservable._warn: neste core em Dart puro não existe
  // `ObserverLogger`/`kDebugMode` (ambos do lado Flutter), então warnings
  // de mau uso são despachados como `WarningEvent`s para
  // `ObserverConfig.inspectors` — registre um `ConsoleInspector` para
  // vê-los impressos.
  void _warn(String message, {String? suggestion}) {
    ObserverProtocol.warningRaised(
      warningCode: 'scope.warning',
      message: message,
      suggestion: suggestion,
      objectId: objectId,
    );
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onWarning(
        WarningEvent(
          message,
          suggestion: suggestion,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
  }
}
