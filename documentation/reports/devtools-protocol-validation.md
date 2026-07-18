# Validação da Fase 1 — Observer Protocol

English version: [devtools-protocol-validation.en.md](devtools-protocol-validation.en.md)

## Decisão

**READY COM RESTRIÇÕES.** O protocolo v1 já sustenta consumers externos para
observables escalares, computed, Observer, `watch`, effects, scopes e workers,
sem depender de Flutter DevTools. As restrições reais estão na seção final:
coleções reativas ainda mantêm somente a instrumentação legada e objetos
anteriores a uma nova sessão não são redescobertos automaticamente.

## Análise anterior à implementação

O fluxo legado foi preservado:

| Evento legado | Criação/dispatch principal |
| --- | --- |
| `ObservableCreateEvent` | `CoreObservable` chama `dispatchToInspectors`; o wrapper usa `ObserverLogger` somente para console |
| `ObservableUpdateEvent` | `CoreObservable` após mudança real; wrappers evitam dispatch duplicado |
| `ObservableDisposeEvent` | `CoreObservable`/`CoreComputed`; wrappers mantêm apenas o log de console |
| `TrackEvent` | `DependencyTracker.reportRead`, na primeira leitura distinta da execução |
| `WarningEvent` | `CoreObservable`, `ReactiveScope` e `ObserverLogger.warn` |
| `EffectEvent` | `effect`, depois da execução bem-sucedida |
| `ScopeDisposeEvent` | `ReactiveScope.dispose` |

`ObserverLogger` continua responsável pelo console e só despacha quando o
chamador pede. `RecordingInspector` continua limitando sua lista com
`removeAt(0)` depois de `maxEvents`. Trackers continuam usando a pilha do
`DependencyTracker`; o registro de listeners é substituído a cada execução,
removendo dependências antigas. `ReactiveScope` mantém disposers em ordem
LIFO e isola suas falhas.

O plano aplicado separou modelos, eventos, snapshot e runtime interno; manteve
os eventos/classes existentes; acrescentou retornos rápidos no caminho
desativado; e cobriu identidade, lifecycle, grafo, scopes, valores, buffer,
consumer tardio, isolamento e compatibilidade. Os principais riscos eram uma
quebra para `implements ObserverInspector`, dispatch duplicado, retenção de
valores do usuário e mudança na propagação de exceções.

## Arquitetura e APIs

O fluxo final é:

```text
core reativo -> Observer Protocol -> ObserverConfig.inspectors
                                      -> consumers opt-in
```

`ObserverProtocolInspector extends ObserverInspector` é a capacidade opt-in.
Não há uma segunda lista de inspectors. `ObserverProtocol`,
`ObserverProtocolConfig`, eventos, IDs, summaries e snapshots são exportados
por `all_observer.dart` e `core.dart`.

Os arquivos novos estão divididos em contextos pequenos:

- `lib/src/protocol/model`: identidade, kind e resumo de valor;
- `lib/src/protocol/events`: envelope e eventos por domínio;
- `lib/src/protocol/snapshot`: estado público imutável;
- `lib/src/protocol/internal`: sessão, registry, buffer e runtimes;
- `test/devtools`: testes contratuais;
- `benchmark`: harness reproduzível;
- `documentation/en`, `documentation/pt-BR` e `documentation/reports`: uso,
  validação e números.

Os arquivos existentes alterados são os barrels, configuração/logging,
`CoreObservable`, `CoreComputed`, `DependencyTracker`, `ReactiveScope`,
`Observable`, `Computed`, effect, Observer, `watch`, workers, READMEs e
arquitetura. A semântica reativa e os eventos legados foram preservados.

## Contrato do protocolo

- `protocolVersion`: constante independente do pacote, atualmente `1`;
- `sessionId`: identidade da inicialização; muda em `configure` e
  `startNewSession`;
- `eventId`: único na sessão;
- `sequenceNumber`: contador estritamente crescente na sessão;
- `timestampMicros`: relógio de parede de `DateTime.now()`;
- `objectId`/`scopeId`/`trackerId`: `ObserverNodeId` monotônico, estável e sem
  uso de label ou `hashCode`;
- `runId`: identidade única da execução rastreada;
- `nodeKind`: observable, computed, observer, watch, effect, scope, worker ou
  subscription.

Exemplo representativo:

```dart
NodeUpdatedEvent(
  protocolVersion: 1,
  sessionId: sessionId,
  eventId: 'event-2',
  sequenceNumber: 2,
  timestampMicros: timestamp,
  objectId: counter.objectId,
  kind: ObserverNodeKind.observable,
  oldValueSummary: oldSummary,
  newValueSummary: newSummary,
)
```

Lifecycle: `NodeCreatedEvent`, `NodeUpdatedEvent` e `NodeDisposedEvent`.
Execução: `TrackerRunStartedEvent`, `DependenciesChangedEvent` e
`TrackerRunFinishedEvent`. Scopes: `ScopeCreatedEvent`,
`ScopeResourceRegisteredEvent` e `ProtocolScopeDisposedEvent`. Warnings usam
`WarningRaisedEvent`. O nome do dispose de scope evita colisão com o evento
legado.

O término do tracker ocorre em `finally`, inclui duração monotônica,
dependências finais e `completedWithError`, e nunca substitui a exceção
original.

## Compatibilidade

Foi escolhida a estratégia A, dispatch aditivo: o core mantém o evento legado
e emite o evento v1 por um caminho separado. A adaptação de um evento legado
perderia identidade/grafo; uma bridge não observaria com precisão scopes e
remoções. O dispatch aditivo tem algum custo quando habilitado, mas oferece a
menor chance de regressão e permite retirar o legado futuramente de forma
explícita.

| Mudança | `extends` | `implements` | Breaking | Estratégia |
| --- | ---: | ---: | ---: | --- |
| Nenhum método novo em `ObserverInspector` | preservado | preservado | não | classe legada intacta |
| Consumer v1 | opt-in | opt-in | não | `ObserverProtocolInspector` |
| Registro | igual | igual | não | `ObserverConfig.inspectors` |
| Eventos legados | igual | igual | não | dispatch mantido |

Cada consumer v1 é chamado isoladamente a partir de uma cópia da lista. Uma
exceção é encaminhada a `CoreErrorReporting` e não interrompe consumers
seguintes, registry ou atualização reativa.

## Registry, snapshot e buffer

O registry armazena somente metadados imutáveis: IDs, kinds, labels, nomes de
tipo, timestamps, summaries seguros, arestas atuais e IDs/kinds dos recursos
de scopes. Não guarda valores crus nem referências aos objetos do usuário.
Dispose remove o nó e arestas relacionadas. O estado privado de descarte de
trackers usa `Expando<bool>`; não existe `isDisposed` público no tracker.

`ObserverProtocol.snapshot()` copia e torna imutáveis nós ativos,
dependências e scopes. `lastSequenceNumber` permite aplicar somente eventos
posteriores ao snapshot. O consumer pode ser registrado depois da criação dos
objetos na mesma sessão.

O ring buffer remove o evento mais antigo ao atingir o limite. Tamanho zero
retém zero eventos, continua despachando e contabiliza todos como descartados.
O snapshot informa `droppedEventCount`, `firstAvailableSequence` e
`lastAvailableSequence`.

## Grafo de dependências

Ao final de cada run, o conjunto final deduplicado substitui atomicamente o
anterior. Para `enabled ? user : fallback`, por exemplo:

```text
run 1: current={enabled,user}, added={enabled,user}, removed={}
run 2: current={enabled},      added={},             removed={user}
```

A dependência mantida permanece em `current`, mas não em `added` ou
`removed`. `DependenciesChangedEvent` só é emitido quando o conjunto muda.

## Segurança de valores

Sem captura, somente o tipo é registrado. Com captura, null/bool/números/enums
e strings limitadas podem exibir conteúdo; List/Map/Set/`Uint8List` exibem
somente tipo e tamanho. Strings suspeitas são redigidas e strings longas são
truncadas. `redactValue` permite política explícita e falha de forma fechada.
Objetos arbitrários não são percorridos nem passam por `toString()`, portanto
implementações lentas, enormes, circulares ou que lançam não afetam o update.

## Testes e benchmark

Os 21 casos em `test/devtools` cobrem:

| Arquivo | Lacuna comprovada |
| --- | --- |
| `instance_identity_contract_test.dart` | labels duplicados, sessão, IDs, sequência e stack opt-in |
| `inspector_dispatch_contract_test.dart` | camada única, `implements` legado, isolamento, modo desativado e registry opt-out |
| `dependency_graph_contract_test.dart` | added/retained/removed, erro em tracker e snapshot tardio |
| `tracker_lifecycle_contract_test.dart` | lifecycle/recompute de computed, runs do Observer e grafo condicional completo de `watch` por build |
| `scope_registry_contract_test.dart` | identidade de recursos e contagem de disposers com falha |
| `value_safety_contract_test.dart` | `toString` hostil/circular, coleções grandes, bytes, strings, redação e buffers 0/1/10/1000 |

Resultado final: `dart analyze` sem issues, suíte contratual com 21 casos e
suíte Flutter completa aprovadas. Os números reproduzíveis estão em
[observer-protocol-benchmark.md](observer-protocol-benchmark.md); na amostra,
o update passou de 0.0357 para 0.4384 µs/op com protocolo ativo e sem consumer.

## Limitações restantes

- `ObservableList`, `ObservableMap` e `ObservableSet` continuam no fluxo
  legado e ainda não aparecem como nós v1 independentes.
- Iniciar outra sessão não redescobre automaticamente objetos já existentes;
  a inicialização deve ocorrer antes de criá-los.
- Não há integração com rotas, Flutter DevTools, VM Service, rede ou UI.
- Não há edição de estado, ações remotas ou detecção automática de leaks.
- Ausência de dispose é dado incompleto, não prova de vazamento.
- Alocações não foram medidas pelo harness baseado em `Stopwatch`.

A próxima fase recomendada é validar o transporte/consumer externo e decidir
explicitamente o contrato das coleções antes de criar qualquer UI. Ela não foi
implementada nesta entrega.
