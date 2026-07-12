# Análise: alien-signals-dart vs all_observer

> Estudo do core do [medz/alien-signals-dart](https://github.com/medz/alien-signals-dart) (v2.3.1, port Dart do alien-signals do StackBlitz — o motor por trás do Vue 3.6). Core inteiro: **1.562 linhas** em 3 arquivos (`system.dart` 533, `preset.dart` 687, `surface.dart` 337). Usado por Solidart, Oref, flutter_compositions e ZenBus.

## Arquitetura em 3 camadas

| Camada | Arquivo | Papel |
|---|---|---|
| **System** | `system.dart` | Motor genérico de grafo reativo. Classe abstrata `ReactiveSystem` com 3 hooks (`update`, `notify`, `unwatched`) e algoritmos prontos (`link`, `unlink`, `propagate`, `checkDirty`). Zero política. |
| **Preset** | `preset.dart` | Implementação padrão: `SignalNode`, `ComputedNode`, `EffectNode`, batching, fila de effects. |
| **Surface** | `surface.dart` | API ergonômica `signal()/computed()/effect()`. |

O ponto estratégico: o **system é público e extensível** — Solidart e Oref não copiam o motor, eles o *estendem*. É isso que criou o ecossistema. O split `core/` vs Flutter do all_observer tem o mesmo espírito, mas o motor não é projetado para terceiros construírem em cima.

## As 7 técnicas centrais do core

**1. Grafo em linked lists intrusivas.** Cada `ReactiveNode` tem `deps/depsTail` e `subs/subsTail`; um `Link` é uma aresta que vive simultaneamente nas duas listas duplamente ligadas. Inserção/remoção O(1), zero hashing, zero snapshot na notificação. Compare com all_observer: `LinkedHashSet` de listeners + snapshot (`toList`) a cada `notifyAll` + uma `List<Disposer>` de closures por recompute — cada onda aloca.

**2. Reuso de links por versão (`cycle`).** A cada rerun, um contador global `cycle` incrementa e `link(dep, sub, cycle)` **reusa o link existente in-place** (só atualiza `version` e avança `depsTail`); ao final, `purgeDeps` remove só a cauda obsoleta. all_observer faz clear-all + resubscribe a cada recompute (`_clearDependencies`) — churn de alocação proporcional ao nº de deps, mesmo quando as deps não mudaram (caso comum).

**3. Bit flags em um único `int` via `extension type`.** `ReactiveFlags` (mutable/watching/recursed/dirty/pending...) — checagens de estado viram uma operação bitwise em um campo, com type safety de custo zero. all_observer usa múltiplos booleans espalhados (`_dirty`, `_flushing`, `_applyingHistoryChange`...). O idioma `extension type const ReactiveFlags._(int) implements int` vale aprender por si só.

**4. Push-pull híbrido.** Escrita faz *push* barato (`propagate` só marca flags `pending/dirty` e enfileira effects); o recompute é *pull* preguiçoso (`checkDirty` no momento da leitura). Um `Computed` que ninguém lê **nunca recomputa**. No all_observer o flush em ondas recomputa Computeds sujos eagerly, lidos ou não. (O resultado glitch-free é o mesmo; a diferença é trabalho evitado.)

**5. Recursão zero — stack explícita.** `propagate` e `checkDirty` usam uma `Stack<T>` própria (struct ligada) em vez de recursão: grafos de profundidade arbitrária sem stack overflow. all_observer usa recursão de call stack limitada por `kMaxNotificationDepth = 100` — é guarda de ciclo, mas também limita profundidade legítima.

**6. `unwatched()` — limpeza automática.** Quando um nó perde o último subscriber, o hook dispara: `Computed` solta as próprias deps (vira coletável), effects param. Reduz vazamento sem `dispose()` manual. No all_observer a limpeza é manual/via `ReactiveScope`.

**7. Fila de effects intrusiva + pragmas.** Effects enfileirados via `nextEffect` (lista ligada singly, O(1), zero alocação) e hot paths anotados com `@pragma('vm:prefer-inline')`, `dart2js:tryInline`, `wasm:prefer-inline`, `vm:align-loops` — e há um **teste que verifica se os pragmas continuam presentes** (`dart2js_pragma_test.dart`).

## Onde o all_observer é melhor

O alien-signals paga a performance com opacidade: constantes mágicas (`flags & 60`), `identical()` como igualdade (sem `equals` customizável — mudar para valor igual re-propaga), **nenhuma** camada de observabilidade, nenhum isolamento de erro por listener (um effect que lança derruba o flush), e nada de coleções observáveis, async (`ObservableFuture/Stream` + geração), history, store, inspectors ou docs bilíngues. São nichos diferentes: alien-signals é um *motor* minimalista; all_observer é uma *biblioteca de aplicação* com DX e diagnóstico.

## Recomendações (respeitando o ADR-0001)

O ADR-0001 decidiu explicitamente contra versioning por nó "sem causa". Concordo — nada aqui justifica reescrever o core sem evidência. Ordem sugerida:

**Sem tocar no core (fazer já):**

1. **Benchmark comparativo** — adicionar `alien_signals` como dev dependency do `benchmark/` e medir os mesmos cenários do `bench/propagate.dart` deles (diamante, cadeia profunda, fan-out largo). Isso transforma as decisões abaixo de opinião em dado, e alimenta o RESULTS.md.
2. **README** — incluir `alien_signals` na tabela comparativa exigida (posicionamento: "motor cru mais rápido" vs "biblioteca completa com observabilidade"). Solidart usa alien como motor — bom argumento de contexto.
3. **Testes de mutação de grafo — coberto na 1.5.4**: o suite agora cobre deps que mudam durante dirty checking/flush, descarte de subscribers durante update, perda do último subscriber, `CoreComputed.close()` durante recompute, `untracked()` dentro de `CoreComputed`, revert de valor no mesmo batch, isolamento de exceções no flush e smoke test Dart2JS de `core.dart`/`engine.dart`. Manter esses testes ativos como regressão.
4. **Effect com cleanup retornável** — `effect(() { ...; return () => sub.cancel(); })`, cleanup executado antes de cada rerun e no dispose. Padrão consagrado (React/Solid/alien), pequeno, e resolve um caso real de vazamento em effects assíncronos.

**Micro-otimizações localizadas (se o benchmark apontar):**

5. **Auto-release estilo `unwatched`** — `CoreComputed` soltar as deps quando o último listener sai (hoje só via scope/close).
6. **Consolidar booleans em bit flags** no `CoreComputed`/`CoreObservable` e anotar hot paths (`reportRead`, `notifyOrQueue`, `notifyAll`) com `@pragma('vm:prefer-inline')`.
7. **Reuso de subscription em recompute** — em vez de clear-all + resubscribe, comparar a lista lida com a anterior e só religar o delta. É a versão "leve" do truque do `cycle`, sem versioning por nó (ADR-0001 preservado).

**Estrutural (só com evidência forte):**

8. Linked lists intrusivas e pull lazy no lugar do flush eager em ondas. Ganho real em grafos grandes; custo alto em legibilidade — exatamente o tipo de mudança que o ADR-0001 manda não fazer sem causa. Deixar o benchmark do item 1 decidir.

## Referências

- Core: `lib/src/system.dart`, `lib/src/preset.dart` no repo
- Bench deles: `bench/propagate.dart`
- Algoritmo original: [stackblitz/alien-signals](https://github.com/stackblitz/alien-signals)
