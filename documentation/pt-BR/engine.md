# O motor reativo (`package:all_observer/engine.dart`)

O `all_observer` entrega sua camada mais baixa como um **motor público,
independente e em Dart puro**, sobre o qual qualquer pessoa pode construir
uma biblioteca reativa própria. Os `Observable`/`Computed` do próprio
pacote rodam nele — você recebe exatamente a mesma maquinaria.

```
┌─────────────────────────────────────────────┐
│  all_observer.dart   (Flutter: Observer,    │
│  watch(), coleções, async, workers)         │
├─────────────────────────────────────────────┤
│  core.dart           (CoreObservable,       │
│  CoreComputed, BatchScope, inspectors)      │
├─────────────────────────────────────────────┤
│  engine.dart         (ReactiveEngine —      │
│  o grafo. Zero política. Seu para estender.)│
└─────────────────────────────────────────────┘
```

## O que o motor é (e deliberadamente não é)

O motor possui **apenas a mecânica do grafo**:

- um grafo de dependências de `ReactiveNode`s conectados por
  `ReactiveLink`s (listas duplamente ligadas intrusivas: inserção/remoção
  O(1), sem hashing, sem churn de alocação quando as mesmas dependências
  são re-rastreadas);
- estado do nó em bit flags num único `int` (`ReactiveFlags`);
- fase **push**: `propagate` percorre subscribers iterativamente (pilha
  explícita — a profundidade do grafo é limitada pelo heap, não pela call
  stack) marcando-os como "talvez obsoletos" (`pending`) e notificando
  watchers;
- fase **pull**: `checkDirty` confirma a obsolescência preguiçosamente,
  atualizando dependências obsoletas das mais profundas para cima, apenas
  quando um valor é de fato necessário.

Ele **não tem política**. O que significa "atualizar um nó", como effects
são agendados, o que acontece quando um nó perde seu último subscriber —
tudo isso é delegado a você por três hooks abstratos:

| Hook | Chamado quando | Você tipicamente |
|---|---|---|
| `bool update(node)` | um nó obsoleto precisa se atualizar | recomputa o valor; retorna `true` só se mudou (seu `equals` mora aqui — retornar `false` corta a propagação abaixo deste nó) |
| `void notify(node)` | um nó com `watching` é alcançado no `propagate` | enfileira o nó para rodar após a escrita/batch atual |
| `void unwatched(node)` | um nó perde seu último subscriber | libera recursos, solta dependências, para trabalho |

## Tutorial: construa seus próprios signals em ~100 linhas

Uma versão completa e executável de tudo abaixo vive em
`test/engine/fixtures/mini_preset.dart` (exercitada por
`test/engine/reactive_engine_test.dart`). Os passos essenciais:

### 1. A subclasse do motor e o estado global de rastreamento

```dart
import 'package:all_observer/engine.dart';

int cycle = 0;                 // contador de ciclos p/ o link()
ReactiveNode? activeSub;       // quem está (re)computando agora
MyEffect? queuedHead, queuedTail;

class MyEngine extends ReactiveEngine {
  @override
  bool update(ReactiveNode node) => switch (node) {
        MyComputed<Object?>() => node.recompute(),
        MySignal<Object?>() => node.commit(),
        _ => false,
      };

  @override
  void notify(ReactiveNode node) {
    final MyEffect e = node as MyEffect;
    e.flags = e.flags & ~ReactiveFlags.watching; // evita fila dupla
    // anexa e à lista ligada queuedHead/queuedTail...
  }

  @override
  void unwatched(ReactiveNode node) {
    // ex.: um computed que ninguém observa: solta deps, marca dirty.
  }
}

final MyEngine engine = MyEngine();
```

### 2. Um signal: escrever = marcar + propagar; ler = ligar

```dart
class MySignal<T> extends ReactiveNode {
  MySignal(this._current)
      : _pending = _current,
        super(flags: ReactiveFlags.mutable);
  T _current, _pending;

  void set(T v) {
    if (identical(_pending, v)) return;
    _pending = v;
    flags = ReactiveFlags.mutableDirty;      // "mudou com certeza"
    final subs = this.subs;
    if (subs != null) {
      engine.propagate(subs);                // push: marcações baratas
      flushEffects();                        // ou adia se em batch
    }
  }

  T get() {
    if (flags.hasAny(ReactiveFlags.dirty)) commit();
    final sub = activeSub;
    if (sub != null) engine.link(this, sub, cycle);  // auto-rastreio
    return _current;
  }

  bool commit() {
    flags = ReactiveFlags.mutable;
    if (identical(_current, _pending)) return false;
    _current = _pending;
    return true;
  }
}
```

### 3. Um computed: pull preguiçoso com re-rastreamento

A disciplina de re-rastreamento é o coração do motor. A cada re-execução:

1. `depsTail = null` — zera o *cursor de re-rastreamento*;
2. seta `flags = ReactiveFlags.mutableChecking`, troca `activeSub` para o
   nó, incrementa `++cycle`;
3. roda a computação do usuário — cada `get()` que ela toca chama
   `engine.link(dep, this, cycle)`, que **reusa links existentes no
   lugar** (uma re-execução que lê as mesmas coisas não aloca nada);
4. num `finally`: restaura `activeSub`, limpa `recursedCheck`, e desliga
   tudo que sobrou *depois* do cursor — dependências não relidas desta vez
   (é assim que branches condicionais deixam de ser dependências).

```dart
T get() {
  final f = flags;
  if (f.hasAny(ReactiveFlags.dirty) ||
      (f.hasAny(ReactiveFlags.pending) && _confirma())) {
    if (recompute()) {                        // o valor mudou de fato
      final subs = this.subs;
      if (subs != null) engine.shallowPropagate(subs); // pending -> dirty
    }
  } else if (f == ReactiveFlags.none) {
    // primeira avaliação: mesma dança de rastreamento, sem notificação
  }
  final sub = activeSub;
  if (sub != null) engine.link(this, sub, cycle);
  return _value as T;
}

bool _confirma() {
  if (engine.checkDirty(deps!, this)) return true;  // pull confirma
  flags = flags & ~ReactiveFlags.pending;           // alarme falso
  return false;
}
```

`pending` vs `dirty` é o que torna escritas baratas: `propagate` só diz
"*talvez* obsoleto"; `checkDirty` sobe o grafo e, se algum `equals` cortou
a mudança no caminho, seu computed nem chega a re-rodar.

### 4. Um effect: um nó `watching` que o motor notifica

Crie o nó com `flags: ReactiveFlags.watching`, rode-o uma vez com a mesma
disciplina de rastreamento de um computed e, quando `notify` disparar,
enfileire-o; no flush, re-execute (ou antes rode `checkDirty` para pular
alarmes falsos). Parar um effect = setar `flags = none` e desligar suas
deps em ordem reversa — o motor chama `unwatched` cadeia acima
automaticamente.

### 5. Batching

Mantenha um contador `batchDepth`: escritas ainda fazem `propagate`
(marcar é barato e idempotente), mas o flush da fila de effects só
acontece quando o batch mais externo termina. A deduplicação vem de graça
— um nó já marcado não é re-enfileirado.

## Regras da estrada

- **Um único isolate.** O motor não tem locks; use-o de um isolate só.
- **Sempre pareie a dança de rastreamento com `try`/`finally`** (restaurar
  `activeSub`, limpar `recursedCheck`, purgar links obsoletos) — mesmo
  quando a computação do usuário lança exceção.
- **`update()` precisa ser honesto.** Retornar `true` sem mudança causa
  sobre-notificação; retornar `false` com mudança deixa os nós abaixo
  famintos.
- **Não toque em `flags` fora das transições documentadas** — os
  algoritmos de propagação dependem delas com precisão.
- As máscaras nomeadas (`ReactiveFlags.mutableDirty`, `stale`,
  `watchingOrChecking`, …) existem para o seu código nunca conter um `17`
  solto.

## Como o próprio all_observer liga o motor

O preset do pacote vive em `lib/src/core/engine_bridge.dart` (exportado
pelo `core.dart`) e integra por exatamente duas costuras:

- `DependencyTracker.reportRead` — enquanto um `CoreComputed` recomputa,
  cada leitura liga o nó de motor daquele registry como dependência;
- `ListenerRegistry.notifyAll` — quando o flush em duas fases do
  `BatchScope` entrega uma mudança, o nó do registry propaga pelo motor, e
  o `WatcherNode` interno de cada computed vivo agenda um pull na fase 2
  do mesmo flush.

É por isso que `Observable`, coleções, async e widgets não precisaram de
nenhuma mudança — e tudo que você já sabe do `core_concepts.md` continua
valendo.

`effect()` continua sendo um scheduler de nível mais alto sobre a mesma
pilha de rastreamento. Ele registra escritas feitas enquanto seu callback
está rastreado e suprime apenas a autoinvalidação daquele flush de batch
atual; escritas externas posteriores ainda propagam pela ponte do motor e
rodam o effect de novo. Isso mantém o comportamento de mutação de grafo
push-pull compatível com as garantias de batch do pacote.
