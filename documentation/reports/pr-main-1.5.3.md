# Relatório de testes e release — all_observer 1.5.3

## Tipo de mudança

**Tipo:** Fix + Infra + Testes  
**Contexto:** release patch para alinhar falhas síncronas de
`ObservableStream` com `ObservableFuture` e ampliar a proteção contra
regressões em projetos pequenos e grandes.

Não há breaking changes, alteração de enums ou mudança no comportamento do
motor reativo.

---

## O que foi feito

1. Exceções síncronas de `streamFactory` agora viram `AsyncError`.
2. Falhas assíncronas ao cancelar uma `StreamSubscription` são isoladas e
   encaminhadas por `CoreErrorReporting`.
3. Foram adicionados testes de contratos públicos, coleções, listeners,
   descarte, escala, retenção, fuzz do grafo e performance.
4. O app de exemplo ganhou scaffold web e build release no CI.
5. A versão do pacote e do exemplo foi atualizada para `1.5.3`.

---

## Resumo quantitativo

| Camada | Resultado |
|---|---:|
| Suíte principal | 354 testes passando |
| Novos cenários desta atualização | 32 |
| Guards de performance | 2 passando |
| Testes existentes do `example` | 14 passando |
| Build `example` web release | Passou |
| Dry-run de compatibilidade Wasm | Passou |
| Análise estática | Sem problemas |

> O diretório `example/test` não recebeu testes novos nesta atualização.
> Seus 14 testes existentes foram reexecutados. A novidade na camada
> `example` é o scaffold web e o smoke build release executado pelo CI.

---

## Inventário dos testes novos

### Segurança assíncrona e workers

Arquivo:
`test/regressions/async_worker_safety_regression_test.dart`

| Cenário | Resultado esperado |
|---|---|
| `streamFactory` lança sincronamente | `run()` não propaga; estado vira `AsyncError` |
| `cancel()` falha assincronamente | erro é reportado e não fica não tratado |
| `cancelOnError: true` | assinatura é cancelada e eventos posteriores são ignorados |
| `interval` descartado no cooldown | callback pendente não executa |
| `debounce` descartado repetidamente | dispose idempotente e nenhum callback tardio |

### Contratos de coleções

Arquivo:
`test/regressions/collection_contract_regression_test.dart`

| Cenário | Resultado esperado |
|---|---|
| `length=`, `removeAt`, `insert` | uma notificação por mutação |
| Operações após `close()` | dados permanecem inalterados |
| Iteração de `ObservableSet` | leitura é rastreada pelo `Observer` |
| `ObservableSet.lookup()` | leitura é rastreada pelo `Observer` |
| Modelo de `ObservableList` | 1.000 operações equivalentes a `List` |
| Modelo de `ObservableMap` | 1.000 operações equivalentes a `Map` |
| Modelo de `ObservableSet` | 1.000 operações equivalentes a `Set` |

As sequências model-based usam seeds fixas, portanto uma falha é reproduzível.

### Escala e churn

Arquivo:
`test/regressions/scale_and_churn_regression_test.dart`

| Cenário | Massa |
|---|---:|
| Subscriptions de widgets | 500 `Observer`s |
| Montagem e desmontagem repetida | 200 ciclos |
| Fan-out de valores derivados | 1.000 `Computed`s |
| `close()` durante notificação | snapshot atual permanece consistente |

### Retenção prolongada

Arquivo:
`test/regressions/memory_retention_stress_test.dart`

- Executa 20.000 ciclos de criação, tracking, atualização e descarte.
- Confirma ausência de links restantes por `hasListeners`.
- Aplica teto amplo de 256 MiB para crescimento RSS descontrolado.

Esse teste é um guard contra retenção grosseira. Ele não substitui análise de
heap com DevTools.

### Fuzz determinístico do grafo

Arquivo:
`test/engine/randomized_graph_fuzz_test.dart`

- 40 fontes reativas.
- 300 nós `CoreComputed`.
- 1.000 mutações com seed `20260709`.
- Comparação contra modelo topológico independente.
- Descarte final com verificação de ausência de listeners.

### Listeners e descarte de CoreComputed

Arquivo:
`test/regressions/public_listener_edge_contract_test.dart`

| Cenário | Resultado esperado |
|---|---|
| `Observable.addListener/removeListener` | notificações param após remoção |
| `Computed.addListener/removeListener` | notificações param após remoção |
| Primeira leitura depois de `close()` | calcula uma vez, sem subscription |
| `close()` depois da avaliação | último valor permanece congelado |

### APIs públicas e aliases `.obs`

Arquivos:

- `test/observable/observable_extensions_public_test.dart`
- `test/public_entrypoints_test.dart`

Cobrem:

- objetos genéricos, `List`, `Map` e `Set` usando `.obs`;
- cópia defensiva da coleção de origem;
- imports públicos `all_observer.dart`, `core.dart` e `engine.dart`;
- ciclo público de `link/unlink` do motor.

### AsyncState

Arquivo:
`test/observable/async/async_state_test.dart`

Novos cenários:

- `maybeWhen` para loading, data e error;
- consistência de `hashCode`;
- mensagens de diagnóstico de `toString()`.

### Performance

Arquivo:
`benchmark/performance_guard_test.dart`

- Compara `Observable` com `ValueNotifier`.
- Compara `ObservableList.addAll` com `List.addAll`.
- Usa mediana de cinco execuções e razões relativas.
- Os limites são amplos e detectam regressões catastróficas em debug; não são
  metas de performance release.

---

## Recursos impactados

- `ObservableStream`: tratamento de falha síncrona e isolamento do cancelamento.
- `CoreErrorReporting`: recebe falhas assíncronas de cancelamento.
- Pipeline CI: performance guards e build web release do exemplo.
- App de exemplo: nova plataforma web.
- Documentação async e changelog.

Não há alteração em rotas, DI, storage, banco, filas ou contratos externos.

---

## Sugestão de testes

**Cenário 1 — factory de stream falha antes de retornar a stream**

- **Dado que** uma `ObservableStream` usa uma factory que lança imediatamente
- **Quando** `run()` for chamado
- **Então** nenhuma exceção deve escapar e o valor deve ser `AsyncError`

**Cenário 2 — descarte sob carga**

- **Dado que** existem muitos `Observer`s e `Computed`s ativos
- **Quando** todos forem desmontados e fechados
- **Então** nenhum observable deve manter listeners

**Cenário 3 — coleções sob operações variadas**

- **Dado que** uma coleção observável e uma coleção Dart comum começam iguais
- **Quando** a mesma sequência de operações for aplicada
- **Então** ambas devem terminar iguais e as notificações devem respeitar o
  contrato

**Cenário 4 — publicação web**

- **Dado que** as dependências do exemplo estão instaladas
- **Quando** `flutter build web --release` for executado
- **Então** o build deve finalizar sem erro e o dry-run Wasm deve passar

### Critérios de aceite

- [ ] `flutter analyze` finaliza sem problemas.
- [ ] Os 354 testes da suíte principal passam.
- [ ] Os 2 guards de performance passam.
- [ ] Os 14 testes do exemplo passam.
- [ ] O build web release do exemplo passa.
- [ ] Falha síncrona da factory produz `AsyncError`.
- [ ] Falha de cancelamento não vira erro assíncrono não tratado.
- [ ] Nenhum breaking change é introduzido.

---

## Massa de teste

| Campo | Valor |
|---|---|
| Seed do fuzz do grafo | `20260709` |
| Fontes reativas no fuzz | `40` |
| Computeds no fuzz | `300` |
| Mutações no fuzz | `1.000` |
| Ciclos de retenção | `20.000` |
| Observers simultâneos | `500` |
| Computeds simultâneos | `1.000` |
| Ciclos de montagem/desmontagem | `200` |
| Limite RSS | `256 MiB` |

---

## Riscos de regressão

> **Atenção:** consumidores que antes dependiam de uma exceção síncrona
> escapar de `ObservableStream.run()` agora recebem `AsyncError`. Essa é uma
> correção compatível com o contrato de estado assíncrono, mas altera esse
> caso de falha específico.

> **Atenção:** guards de RSS e tempo são intencionalmente amplos. Eles detectam
> regressões grandes, mas não substituem profiling em hardware de referência.

> **Atenção:** o CI passa a executar build web release, aumentando o tempo do
> pipeline.

---

## Classificação da versão

Versão proposta: `1.5.3`.

Classificação SemVer: patch, porque corrige tratamento de erro, amplia testes e
CI e não remove nem altera assinaturas públicas. Não há breaking changes.
