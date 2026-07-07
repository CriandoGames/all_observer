import '../engine/reactive_engine.dart';

/// The `all_observer` preset of the public [ReactiveEngine] (engine v2,
/// Fase 2): the concrete engine instance plus the node types that bridge
/// the engine graph to the package's registry-based world.
///
/// Three node kinds participate:
///
/// - [RegistrySignalNode] — the engine identity of a `ListenerRegistry`
///   (a plain `CoreObservable`, a reactive collection, anything that
///   notifies through a registry). Created lazily on first tracked read.
/// - [ComputedEngineNode] — the engine identity of a `CoreComputed`. Its
///   `update`/`unwatched` behavior is delegated back to the owning
///   `CoreComputed` through callbacks, so `equals` filtering and inspector
///   events stay where they always lived.
/// - [WatcherNode] — an effect-like node owned by a `CoreComputed` that has
///   external listeners; it is what turns lazy engine marking into the
///   package's eager listener notification, by scheduling a pull through
///   `BatchScope.queueDirtyFlush` (wired via callback to avoid an import
///   cycle).
///
/// O preset `all_observer` do [ReactiveEngine] público (motor v2, Fase 2):
/// a instância concreta do motor mais os tipos de nó que fazem a ponte
/// entre o grafo do motor e o mundo baseado em registries do pacote.
///
/// Três tipos de nó participam:
///
/// - [RegistrySignalNode] — a identidade no motor de um `ListenerRegistry`
///   (um `CoreObservable` comum, uma coleção reativa, qualquer coisa que
///   notifique por um registry). Criado preguiçosamente na primeira
///   leitura rastreada.
/// - [ComputedEngineNode] — a identidade no motor de um `CoreComputed`.
///   Seu comportamento de `update`/`unwatched` é delegado de volta ao
///   `CoreComputed` dono através de callbacks, então o filtro `equals` e
///   os eventos de inspector continuam onde sempre viveram.
/// - [WatcherNode] — um nó tipo effect, de posse de um `CoreComputed` com
///   listeners externos; é o que converte a marcação preguiçosa do motor na
///   notificação ansiosa de listeners do pacote, agendando um pull via
///   `BatchScope.queueDirtyFlush` (ligado por callback para evitar ciclo de
///   import).
final class ObserverEngine extends ReactiveEngine {
  ObserverEngine._();

  /// The single engine instance behind the whole package.
  ///
  /// A única instância do motor por trás do pacote inteiro.
  static final ObserverEngine instance = ObserverEngine._();

  /// The node currently (re)computing, if any — reads reaching
  /// `DependencyTracker.reportRead` while this is non-null are linked as
  /// engine dependencies of it.
  ///
  /// O nó atualmente (re)computando, se houver — leituras que chegam a
  /// `DependencyTracker.reportRead` enquanto isto é não-nulo são ligadas
  /// como dependências dele no motor.
  ReactiveNode? activeSub;

  /// Monotonic tracking-cycle counter (see [ReactiveEngine.link]).
  ///
  /// Contador monotônico de ciclos de rastreamento (ver
  /// [ReactiveEngine.link]).
  int cycle = 0;

  @override
  bool update(ReactiveNode node) {
    return switch (node) {
      ComputedEngineNode() => node.onEngineUpdate(),
      RegistrySignalNode() => node.didUpdate(),
      _ => false,
    };
  }

  @override
  void notify(ReactiveNode node) {
    if (node is WatcherNode) {
      // Strip `watching` so repeated writes in the same wave don't
      // re-notify; the owner restores it after the scheduled pull runs.
      // Remove `watching` para que escritas repetidas na mesma onda não
      // re-notifiquem; o dono restaura após o pull agendado rodar.
      node.flags = node.flags & ~ReactiveFlags.watching;
      node.onInvalidate();
    }
  }

  @override
  void unwatched(ReactiveNode node) {
    switch (node) {
      case ComputedEngineNode():
        node.onEngineUnwatched();
      case _:
        break; // registry nodes stay alive / nós de registry seguem vivos
    }
  }
}

/// Engine identity of a `ListenerRegistry`-backed source (observable,
/// collection, …). Marked `mutable | dirty` at notification time; pulling
/// it simply confirms "yes, it changed" — the actual value equality was
/// already filtered by the owner before notifying.
///
/// Identidade no motor de uma fonte baseada em `ListenerRegistry`
/// (observável, coleção, …). Marcado `mutable | dirty` no momento da
/// notificação; puxá-lo simplesmente confirma "sim, mudou" — a igualdade de
/// valor real já foi filtrada pelo dono antes de notificar.
final class RegistrySignalNode extends ReactiveNode {
  /// Creates the node in its resting state. / Cria o nó em estado de
  /// repouso.
  RegistrySignalNode() : super(flags: ReactiveFlags.mutable);

  /// Confirms the pending change (see [ReactiveEngine.update]).
  ///
  /// Confirma a mudança pendente (ver [ReactiveEngine.update]).
  bool didUpdate() {
    flags = ReactiveFlags.mutable;
    return true;
  }
}

/// Engine identity of a `CoreComputed`, delegating engine callbacks to the
/// owning instance (which keeps `equals`, memoization and inspector events).
///
/// Identidade no motor de um `CoreComputed`, delegando os callbacks do
/// motor à instância dona (que mantém `equals`, memoização e eventos de
/// inspector).
final class ComputedEngineNode extends ReactiveNode {
  /// Creates the node wired to its owner's recompute/cleanup callbacks.
  ///
  /// Cria o nó ligado aos callbacks de recomputação/limpeza do dono.
  ComputedEngineNode({
    required this.onEngineUpdate,
    required this.onEngineUnwatched,
  }) : super(flags: ReactiveFlags.none);

  /// Recomputes the owner and reports whether the value changed (`equals`
  /// -filtered) — the engine's propagation-cut hook.
  ///
  /// Recomputa o dono e reporta se o valor mudou (filtrado por `equals`) —
  /// o gancho de corte de propagação do motor.
  final bool Function() onEngineUpdate;

  /// Called when the last engine subscriber goes away (auto-release).
  ///
  /// Chamado quando o último subscriber no motor some (auto-liberação).
  final void Function() onEngineUnwatched;
}

/// Effect-like node bridging engine invalidation to external listener
/// notification for a `CoreComputed` that currently has listeners.
///
/// Nó tipo effect fazendo a ponte entre a invalidação do motor e a
/// notificação de listeners externos para um `CoreComputed` que atualmente
/// tem listeners.
final class WatcherNode extends ReactiveNode {
  /// Creates a watcher that calls [onInvalidate] when its dependency (the
  /// owning computed's node) may have changed.
  ///
  /// Cria um watcher que chama [onInvalidate] quando sua dependência (o nó
  /// do computed dono) pode ter mudado.
  WatcherNode({required this.onInvalidate})
    : super(flags: ReactiveFlags.watching);

  /// Owner-provided scheduling callback (queues a pull in the current
  /// batch/flush).
  ///
  /// Callback de agendamento fornecido pelo dono (enfileira um pull no
  /// batch/flush atual).
  final void Function() onInvalidate;
}

/// Unlinks every dependency of [sub] after its re-tracking cursor
/// (`depsTail`) — i.e. the dependencies not re-confirmed by the latest run.
///
/// Desliga toda dependência de [sub] após seu cursor de re-rastreamento
/// (`depsTail`) — isto é, as dependências não reconfirmadas pela última
/// execução.
void purgeDeps(ReactiveNode sub) {
  final ReactiveLink? tail = sub.depsTail;
  ReactiveLink? dep = tail != null ? tail.nextDep : sub.deps;
  while (dep != null) {
    dep = ObserverEngine.instance.unlink(dep, sub);
  }
}

/// Unlinks every dependency of [sub], newest first.
///
/// Desliga toda dependência de [sub], da mais nova para a mais antiga.
void disposeAllDepsInReverse(ReactiveNode sub) {
  ReactiveLink? link = sub.depsTail;
  while (link != null) {
    final ReactiveLink? prev = link.prevDep;
    ObserverEngine.instance.unlink(link, sub);
    link = prev;
  }
}
