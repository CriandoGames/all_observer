// License note: portions of the graph-propagation algorithms in this file
// derive from third-party code © Johnson Chu and © Seven Du, used under the
// MIT license. Everything else — the engine contract, naming, flag masks
// and documentation — is original to all_observer.
//
// Nota de licença: partes dos algoritmos de propagação de grafo deste
// arquivo derivam de código de terceiros © Johnson Chu e © Seven Du, usadas
// sob a licença MIT. Todo o restante — o contrato do motor, nomes, máscaras
// de flags e documentação — é original do all_observer.

/// Bit flags describing the state of a [ReactiveNode].
///
/// All state a node needs during propagation lives in a single `int`,
/// checked and mutated with bitwise operations — one field read instead of
/// several boolean fields. The `extension type` wrapper gives the flags a
/// distinct static type at zero runtime cost.
///
/// Flags de bits descrevendo o estado de um [ReactiveNode].
///
/// Todo o estado que um nó precisa durante a propagação vive em um único
/// `int`, checado e mutado com operações bitwise — uma leitura de campo em
/// vez de vários booleans. O `extension type` dá às flags um tipo estático
/// distinto com custo zero em runtime.
extension type const ReactiveFlags._(int _raw) implements int {
  /// The underlying bit pattern. / O padrão de bits subjacente.
  int get raw => _raw;

  /// No flags set. / Nenhuma flag ativa.
  static const ReactiveFlags none = ReactiveFlags._(0);

  /// The node can be written to / recomputed in place (signals, computeds).
  ///
  /// O nó pode ser escrito / recomputado no lugar (signals, computeds).
  static const ReactiveFlags mutable = ReactiveFlags._(1);

  /// The node actively watches its dependencies (effect-like nodes).
  ///
  /// O nó observa ativamente suas dependências (nós tipo effect).
  static const ReactiveFlags watching = ReactiveFlags._(2);

  /// Set while the node is being (re)computed; used to detect cycles and
  /// self-writes during recomputation.
  ///
  /// Ativa enquanto o nó está sendo (re)computado; usada para detectar
  /// ciclos e auto-escritas durante a recomputação.
  static const ReactiveFlags recursedCheck = ReactiveFlags._(4);

  /// The node was reached again while [recursedCheck] was active.
  ///
  /// O nó foi alcançado de novo enquanto [recursedCheck] estava ativa.
  static const ReactiveFlags recursed = ReactiveFlags._(8);

  /// The node's value is definitely stale and must be recomputed.
  ///
  /// O valor do nó está definitivamente obsoleto e precisa recomputar.
  static const ReactiveFlags dirty = ReactiveFlags._(16);

  /// The node *may* be stale: some dependency upstream changed, pending a
  /// pull-check ([ReactiveEngine.checkDirty]) to confirm.
  ///
  /// O nó *pode* estar obsoleto: alguma dependência acima mudou, pendente
  /// de uma checagem pull ([ReactiveEngine.checkDirty]) para confirmar.
  static const ReactiveFlags pending = ReactiveFlags._(32);

  // ---- Named masks for the flag combinations the engine checks ----
  // ---- Máscaras nomeadas para as combinações de flags que o motor checa ----

  /// `recursedCheck | recursed | dirty | pending` (= 60).
  static const ReactiveFlags propagationState = ReactiveFlags._(
    4 | 8 | 16 | 32,
  );

  /// `recursedCheck | recursed` (= 12).
  static const ReactiveFlags anyRecursed = ReactiveFlags._(4 | 8);

  /// `dirty | pending` (= 48).
  static const ReactiveFlags stale = ReactiveFlags._(16 | 32);

  /// `recursed | pending` (= 40).
  static const ReactiveFlags recursedPending = ReactiveFlags._(8 | 32);

  /// `mutable | dirty` (= 17).
  static const ReactiveFlags mutableDirty = ReactiveFlags._(1 | 16);

  /// `mutable | pending` (= 33).
  static const ReactiveFlags mutablePending = ReactiveFlags._(1 | 32);

  /// `watching | recursedCheck` (= 6).
  static const ReactiveFlags watchingOrChecking = ReactiveFlags._(2 | 4);

  /// `mutable | recursedCheck` (= 5).
  static const ReactiveFlags mutableChecking = ReactiveFlags._(1 | 4);

  /// Bitwise OR keeping the [ReactiveFlags] type. / OR bitwise mantendo o
  /// tipo [ReactiveFlags].
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  ReactiveFlags operator |(ReactiveFlags other) =>
      ReactiveFlags._(_raw | other._raw);

  /// Bitwise AND keeping the [ReactiveFlags] type. / AND bitwise mantendo o
  /// tipo [ReactiveFlags].
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  ReactiveFlags operator &(ReactiveFlags other) =>
      ReactiveFlags._(_raw & other._raw);

  /// Bitwise complement keeping the [ReactiveFlags] type. / Complemento
  /// bitwise mantendo o tipo [ReactiveFlags].
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  ReactiveFlags operator ~() => ReactiveFlags._(~_raw);

  /// Whether every bit in [mask] is set. / Se todos os bits de [mask] estão ativos.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool hasAll(ReactiveFlags mask) => (_raw & mask._raw) == mask._raw;

  /// Whether at least one bit in [mask] is set. / Se ao menos um bit de [mask] está ativo.
  @pragma('vm:prefer-inline')
  @pragma('dart2js:tryInline')
  @pragma('wasm:prefer-inline')
  bool hasAny(ReactiveFlags mask) => (_raw & mask._raw) != 0;
}

/// A node in the reactive dependency graph.
///
/// Anything that participates in reactivity — a value source (signal-like),
/// a derived value (computed-like) or a side effect (effect-like) — is a
/// [ReactiveNode]. A node keeps two intrusive doubly-linked lists:
///
/// - `deps`/`depsTail`: the nodes *it reads from* (its dependencies);
/// - `subs`/`subsTail`: the nodes *that read it* (its subscribers).
///
/// Each edge between two nodes is one [ReactiveLink], shared by both lists.
/// This gives O(1) insertion/removal with zero hashing and zero snapshot
/// allocation during propagation.
///
/// Um nó no grafo reativo de dependências.
///
/// Tudo que participa da reatividade — uma fonte de valor (tipo signal), um
/// valor derivado (tipo computed) ou um efeito colateral (tipo effect) — é
/// um [ReactiveNode]. Um nó mantém duas listas duplamente ligadas
/// intrusivas:
///
/// - `deps`/`depsTail`: os nós *que ele lê* (suas dependências);
/// - `subs`/`subsTail`: os nós *que o leem* (seus subscribers).
///
/// Cada aresta entre dois nós é um único [ReactiveLink], compartilhado
/// pelas duas listas. Isso dá inserção/remoção O(1) sem hashing e sem
/// alocação de snapshot durante a propagação.
class ReactiveNode {
  /// Creates a node with the given initial [flags]. / Cria um nó com as
  /// [flags] iniciais dadas.
  ReactiveNode({required this.flags});

  /// Current state flags. / Flags de estado atuais.
  ReactiveFlags flags;

  /// Head of this node's dependency list. / Cabeça da lista de dependências.
  ReactiveLink? deps;

  /// Tail of the dependency list (O(1) append; also the re-tracking cursor —
  /// see [ReactiveEngine.link]). / Cauda da lista de dependências (append
  /// O(1); também o cursor de re-rastreamento — ver [ReactiveEngine.link]).
  ReactiveLink? depsTail;

  /// Head of this node's subscriber list. / Cabeça da lista de subscribers.
  ReactiveLink? subs;

  /// Tail of the subscriber list. / Cauda da lista de subscribers.
  ReactiveLink? subsTail;
}

/// One edge of the dependency graph: [sub] depends on [dep].
///
/// The link belongs simultaneously to two doubly-linked lists — the
/// dependency list of [sub] (via `prevDep`/`nextDep`) and the subscriber
/// list of [dep] (via `prevSub`/`nextSub`). [version] records the tracking
/// cycle that last confirmed this edge, letting [ReactiveEngine.link] reuse
/// links in place across re-runs instead of destroying and recreating them.
///
/// Uma aresta do grafo de dependências: [sub] depende de [dep].
///
/// O link pertence simultaneamente a duas listas duplamente ligadas — a
/// lista de dependências de [sub] (via `prevDep`/`nextDep`) e a lista de
/// subscribers de [dep] (via `prevSub`/`nextSub`). [version] registra o
/// ciclo de rastreamento que confirmou esta aresta por último, permitindo
/// que [ReactiveEngine.link] reuse links no lugar entre execuções em vez de
/// destruir e recriar.
final class ReactiveLink {
  /// Creates the edge "[sub] depends on [dep]", confirmed in tracking cycle
  /// [version]. / Cria a aresta "[sub] depende de [dep]", confirmada no
  /// ciclo de rastreamento [version].
  ReactiveLink({
    required this.version,
    required this.dep,
    required this.sub,
    this.prevSub,
    this.nextSub,
    this.prevDep,
    this.nextDep,
  });

  /// Tracking cycle that last touched this edge. / Ciclo de rastreamento
  /// que tocou esta aresta por último.
  int version;

  /// The node being depended on. / O nó do qual se depende.
  final ReactiveNode dep;

  /// The node that depends on [dep]. / O nó que depende de [dep].
  final ReactiveNode sub;

  /// Neighbors in [dep]'s subscriber list. / Vizinhos na lista de
  /// subscribers de [dep].
  ReactiveLink? prevSub, nextSub;

  /// Neighbors in [sub]'s dependency list. / Vizinhos na lista de
  /// dependências de [sub].
  ReactiveLink? prevDep, nextDep;
}

/// Minimal linked stack used to make [ReactiveEngine.propagate] and
/// [ReactiveEngine.checkDirty] iterative instead of recursive, so graph
/// depth is bounded by heap, not by the call stack.
///
/// Pilha ligada mínima usada para tornar [ReactiveEngine.propagate] e
/// [ReactiveEngine.checkDirty] iterativos em vez de recursivos, de modo que
/// a profundidade do grafo seja limitada pelo heap, não pela call stack.
final class EngineStack<T> {
  /// Pushes [value] on top of [prev]. / Empilha [value] sobre [prev].
  EngineStack({required this.value, this.prev});

  /// The payload of this frame. / A carga deste quadro.
  final T value;

  /// The frame below this one, or `null` at the bottom. / O quadro abaixo
  /// deste, ou `null` na base.
  final EngineStack<T>? prev;
}

/// The reusable reactive-graph engine of `all_observer` — public and
/// designed for third parties to build their own reactive layers on top,
/// the same way `all_observer`'s own core will (engine v2, Fase 2).
///
/// The engine owns *only* graph mechanics: linking, unlinking, push-phase
/// marking ([propagate]) and pull-phase staleness confirmation
/// ([checkDirty]). It has **no policy**: what "update a node" means, how
/// effects are scheduled, and what happens when a node loses its last
/// subscriber are all delegated to the three abstract hooks — [update],
/// [notify] and [unwatched].
///
/// The propagation model is push-pull: a write pushes cheap flag marks
/// through the graph ([propagate] marks subscribers `pending`/`dirty` and
/// [notify]-schedules watchers), and actual recomputation is pulled lazily
/// — a node confirms staleness with [checkDirty] only when its value is
/// read. A derived node nobody reads never recomputes.
///
/// O motor reutilizável de grafo reativo do `all_observer` — público e
/// projetado para que terceiros construam suas próprias camadas reativas em
/// cima, do mesmo jeito que o próprio core do `all_observer` fará (motor
/// v2, Fase 2).
///
/// O motor possui *apenas* a mecânica do grafo: ligar, desligar, marcação
/// da fase push ([propagate]) e confirmação de obsolescência da fase pull
/// ([checkDirty]). Ele **não tem política**: o que significa "atualizar um
/// nó", como effects são agendados e o que acontece quando um nó perde seu
/// último subscriber são delegados aos três hooks abstratos — [update],
/// [notify] e [unwatched].
///
/// O modelo de propagação é push-pull: uma escrita empurra marcações
/// baratas de flags pelo grafo ([propagate] marca subscribers como
/// `pending`/`dirty` e agenda watchers via [notify]), e a recomputação real
/// é puxada preguiçosamente — um nó confirma obsolescência com [checkDirty]
/// apenas quando seu valor é lido. Um nó derivado que ninguém lê nunca
/// recomputa.
abstract class ReactiveEngine {
  /// Const constructor so concrete engines can be compile-time singletons.
  /// Construtor const para que motores concretos possam ser singletons de
  /// tempo de compilação.
  const ReactiveEngine();

  /// Recomputes [node]'s value in place and returns whether it actually
  /// changed. Returning `false` cuts propagation below [node] (this is
  /// where an `equals` policy plugs in).
  ///
  /// Recomputa o valor de [node] no lugar e retorna se ele realmente mudou.
  /// Retornar `false` corta a propagação abaixo de [node] (é aqui que uma
  /// política de `equals` se encaixa).
  bool update(ReactiveNode node);

  /// Called during [propagate] for nodes flagged [ReactiveFlags.watching].
  /// Implementations typically queue the node for execution after the
  /// current write/batch completes.
  ///
  /// Chamado durante [propagate] para nós com [ReactiveFlags.watching].
  /// Implementações tipicamente enfileiram o nó para execução após a
  /// escrita/batch atual completar.
  void notify(ReactiveNode node);

  /// Called by [unlink] when [node] loses its last subscriber — the hook
  /// for automatic cleanup (release dependencies, stop work, free caches).
  ///
  /// Chamado por [unlink] quando [node] perde seu último subscriber — o
  /// gancho para limpeza automática (soltar dependências, parar trabalho,
  /// liberar caches).
  void unwatched(ReactiveNode node);

  /// Records that [sub] depends on [dep] in tracking cycle [version].
  ///
  /// Designed to be called for *every* read while [sub] re-runs, in read
  /// order, with `sub.depsTail` reset before the run: existing links are
  /// then reused in place (only `version` is refreshed and the tail cursor
  /// advances), so a re-run whose reads didn't change allocates nothing.
  /// New edges are inserted at the cursor; edges not re-confirmed remain
  /// after the tail and are removed later by the caller (see the preset's
  /// `purgeDeps` pattern in Fase 2).
  ///
  /// Registra que [sub] depende de [dep] no ciclo de rastreamento
  /// [version].
  ///
  /// Projetado para ser chamado a *cada* leitura enquanto [sub] re-executa,
  /// em ordem de leitura, com `sub.depsTail` zerado antes da execução:
  /// links existentes são então reusados no lugar (apenas `version` é
  /// atualizado e o cursor da cauda avança), então uma re-execução cujas
  /// leituras não mudaram não aloca nada. Arestas novas são inseridas no
  /// cursor; arestas não reconfirmadas ficam depois da cauda e são
  /// removidas depois pelo chamador (ver o padrão `purgeDeps` do preset na
  /// Fase 2).
  void link(final ReactiveNode dep, final ReactiveNode sub, final int version) {
    final ReactiveLink? prevDep = sub.depsTail;
    if (prevDep != null && identical(prevDep.dep, dep)) {
      return;
    }
    final ReactiveLink? nextDep = prevDep != null ? prevDep.nextDep : sub.deps;
    if (nextDep != null && identical(nextDep.dep, dep)) {
      nextDep.version = version;
      sub.depsTail = nextDep;
      return;
    }
    final ReactiveLink? prevSub = dep.subsTail;
    if (prevSub != null &&
        prevSub.version == version &&
        identical(prevSub.sub, sub)) {
      return;
    }
    final ReactiveLink newLink = sub.depsTail = dep.subsTail = ReactiveLink(
      version: version,
      dep: dep,
      sub: sub,
      prevDep: prevDep,
      nextDep: nextDep,
      prevSub: prevSub,
      nextSub: null,
    );
    if (nextDep != null) {
      nextDep.prevDep = newLink;
    }
    if (prevDep != null) {
      prevDep.nextDep = newLink;
    } else {
      sub.deps = newLink;
    }
    if (prevSub != null) {
      prevSub.nextSub = newLink;
    } else {
      dep.subs = newLink;
    }
  }

  /// Removes the edge [link] from both lists it belongs to. If the
  /// dependency side loses its last subscriber, [unwatched] fires. Returns
  /// the next link in [sub]'s dependency list (an iteration convenience).
  ///
  /// Remove a aresta [link] das duas listas às quais pertence. Se o lado da
  /// dependência perder seu último subscriber, [unwatched] dispara. Retorna
  /// o próximo link da lista de dependências de [sub] (conveniência de
  /// iteração).
  ReactiveLink? unlink(final ReactiveLink link, final ReactiveNode sub) {
    final ReactiveNode dep = link.dep;
    final ReactiveLink? prevDep = link.prevDep,
        nextDep = link.nextDep,
        nextSub = link.nextSub,
        prevSub = link.prevSub;
    if (nextDep != null) {
      nextDep.prevDep = prevDep;
    } else {
      sub.depsTail = prevDep;
    }
    if (prevDep != null) {
      prevDep.nextDep = nextDep;
    } else {
      sub.deps = nextDep;
    }
    if (nextSub != null) {
      nextSub.prevSub = prevSub;
    } else {
      dep.subsTail = prevSub;
    }
    if (prevSub != null) {
      prevSub.nextSub = nextSub;
    } else if ((dep.subs = nextSub) == null) {
      unwatched(dep);
    }
    return nextDep;
  }

  /// Push phase: starting from [link] (the subscriber list of a node that
  /// just changed), walks the graph iteratively marking subscribers
  /// `pending` (or `dirty` via [shallowPropagate] later) and calling
  /// [notify] on watching nodes. Recursion through mutable nodes is
  /// flattened with an explicit [EngineStack]. [innerWrite] must be `true`
  /// when the write happened inside a running effect, enabling the
  /// re-entrancy bookkeeping ([ReactiveFlags.recursed]).
  ///
  /// Fase push: partindo de [link] (a lista de subscribers de um nó que
  /// acabou de mudar), percorre o grafo iterativamente marcando subscribers
  /// como `pending` (ou `dirty` via [shallowPropagate] depois) e chamando
  /// [notify] nos nós watching. A recursão através de nós mutáveis é
  /// achatada com uma [EngineStack] explícita. [innerWrite] deve ser `true`
  /// quando a escrita aconteceu dentro de um effect em execução, habilitando
  /// a contabilidade de reentrância ([ReactiveFlags.recursed]).
  @pragma('vm:align-loops')
  void propagate(ReactiveLink link, [bool innerWrite = false]) {
    ReactiveLink? next = link.nextSub;
    EngineStack<ReactiveLink?>? stack;

    top:
    do {
      final ReactiveNode sub = link.sub;
      ReactiveFlags flags = sub.flags;

      if (!flags.hasAny(ReactiveFlags.propagationState)) {
        // First visit this wave: mark "maybe stale".
        // Primeira visita nesta onda: marca "talvez obsoleto".
        sub.flags = flags | ReactiveFlags.pending;
        if (innerWrite) {
          sub.flags = sub.flags | ReactiveFlags.recursed;
        }
      } else if (!flags.hasAny(ReactiveFlags.anyRecursed)) {
        // Already marked and not in a recursion scenario: stop here.
        // Já marcado e sem cenário de recursão: para aqui.
        flags = ReactiveFlags.none;
      } else if (!flags.hasAny(ReactiveFlags.recursedCheck)) {
        // Re-reached after a previous recursion: clear and re-mark.
        // Alcançado de novo após recursão anterior: limpa e remarca.
        sub.flags = (flags & ~ReactiveFlags.recursed) | ReactiveFlags.pending;
      } else if (!flags.hasAny(ReactiveFlags.stale) && isValidLink(link, sub)) {
        // A node reading itself mid-recompute (self-dependency).
        // Um nó lendo a si mesmo no meio da recomputação (autodependência).
        sub.flags = flags | ReactiveFlags.recursedPending;
        flags = flags & ReactiveFlags.mutable;
      } else {
        flags = ReactiveFlags.none;
      }

      if (flags.hasAny(ReactiveFlags.watching)) {
        notify(sub);
      }

      if (flags.hasAny(ReactiveFlags.mutable)) {
        final ReactiveLink? subSubs = sub.subs;
        if (subSubs != null) {
          final ReactiveLink? nextSub = (link = subSubs).nextSub;
          if (nextSub != null) {
            stack = EngineStack<ReactiveLink?>(value: next, prev: stack);
            next = nextSub;
          }
          continue;
        }
      }

      if (next != null) {
        link = next;
        next = link.nextSub;
        continue;
      }

      while (stack != null) {
        final ReactiveLink? value = stack.value;
        stack = stack.prev;
        if (value != null) {
          link = value;
          next = link.nextSub;
          continue top;
        }
      }

      break;
    } while (true);
  }

  /// Promotes `pending` subscribers of a node that *confirmed* a change to
  /// `dirty`, notifying watchers. Non-recursive: touches immediate
  /// subscribers only.
  ///
  /// Promove subscribers `pending` de um nó que *confirmou* mudança para
  /// `dirty`, notificando watchers. Não recursivo: toca apenas os
  /// subscribers imediatos.
  @pragma('vm:align-loops')
  void shallowPropagate(ReactiveLink link) {
    ReactiveLink? curr = link;
    do {
      final ReactiveNode sub = curr!.sub;
      final ReactiveFlags flags = sub.flags;
      if ((flags & ReactiveFlags.stale) == ReactiveFlags.pending) {
        sub.flags = flags | ReactiveFlags.dirty;
        if ((flags & ReactiveFlags.watchingOrChecking) ==
            ReactiveFlags.watching) {
          notify(sub);
        }
      }
    } while ((curr = curr.nextSub) != null);
  }

  /// Pull phase: walks [sub]'s dependencies starting at [link] and confirms
  /// whether anything upstream actually changed, calling [update] on stale
  /// mutable dependencies along the way (deepest first, iteratively).
  /// Returns `true` if [sub] must recompute. This is what makes `pending`
  /// cheap: a maybe-stale node only does real work when someone pulls it.
  ///
  /// Fase pull: percorre as dependências de [sub] a partir de [link] e
  /// confirma se algo acima realmente mudou, chamando [update] nas
  /// dependências mutáveis obsoletas pelo caminho (mais profundas primeiro,
  /// iterativamente). Retorna `true` se [sub] precisa recomputar. É isso
  /// que torna `pending` barato: um nó talvez-obsoleto só faz trabalho real
  /// quando alguém o puxa.
  @pragma('vm:align-loops')
  bool checkDirty(ReactiveLink link, ReactiveNode sub) {
    EngineStack<ReactiveLink>? stack;
    int checkDepth = 0;
    bool dirty = false;

    top:
    do {
      final ReactiveNode dep = link.dep;
      final ReactiveFlags flags = dep.flags;

      if (sub.flags.hasAny(ReactiveFlags.dirty)) {
        dirty = true;
      } else if (flags.hasAll(ReactiveFlags.mutableDirty)) {
        final ReactiveLink? subs = dep.subs;
        if (update(dep)) {
          if (subs!.nextSub != null) {
            shallowPropagate(subs);
          }
          dirty = true;
        }
      } else if (flags.hasAll(ReactiveFlags.mutablePending)) {
        stack = EngineStack<ReactiveLink>(value: link, prev: stack);
        link = dep.deps!;
        sub = dep;
        ++checkDepth;
        continue;
      }

      if (!dirty) {
        final ReactiveLink? nextDep = link.nextDep;
        if (nextDep != null) {
          link = nextDep;
          continue;
        }
      }

      while ((checkDepth--) > 0) {
        link = stack!.value;
        stack = stack.prev;
        if (dirty) {
          final ReactiveLink? subs = sub.subs;
          if (update(sub)) {
            if (subs!.nextSub != null) {
              shallowPropagate(subs);
            }
            sub = link.sub;
            continue;
          }
          dirty = false;
        } else {
          sub.flags = sub.flags & ~ReactiveFlags.pending;
        }
        sub = link.sub;
        final ReactiveLink? nextDep = link.nextDep;
        if (nextDep != null) {
          link = nextDep;
          continue top;
        }
      }

      return dirty && sub.flags != ReactiveFlags.none;
    } while (true);
  }

  /// Whether [checkLink] is currently an edge of [sub]'s dependency list.
  /// Used by [propagate] to validate self-dependency scenarios.
  ///
  /// Se [checkLink] é atualmente uma aresta da lista de dependências de
  /// [sub]. Usado por [propagate] para validar cenários de autodependência.
  @pragma('vm:align-loops')
  bool isValidLink(final ReactiveLink checkLink, final ReactiveNode sub) {
    ReactiveLink? link = sub.depsTail;
    while (link != null) {
      if (identical(link, checkLink)) {
        return true;
      }
      link = link.prevDep;
    }
    return false;
  }
}
