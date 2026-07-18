# Observer Protocol v1

O Observer Protocol é o contrato versionado de observabilidade entre o core
reativo do `all_observer` e consumidores externos de diagnóstico. Ele não
depende de Flutter DevTools, navegação, VM Service, rede ou edição de estado.

## Ativação e consumo

O protocolo vem desativado. Consumidores usam a camada existente de
`ObserverInspector`:

```dart
final class AuditInspector extends ObserverProtocolInspector {
  @override
  void onProtocolEvent(ObserverProtocolEvent event) {
    // Exporte, inspecione ou valide o evento imutável.
  }
}

void configureDiagnostics() {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(
      enabled: true,
      eventBufferSize: 1000,
    ),
  );
  ObserverConfig.inspectors.add(AuditInspector());
}
```

`ObserverProtocolInspector` estende `ObserverInspector`; não existe uma
segunda lista de consumers. Classes existentes que estendem ou implementam
`ObserverInspector` não recebem método obrigatório novo e continuam
compilando sem alteração.

## Identidade e ordem

- `observerProtocolVersion` começa em `1` e independe da versão do pacote.
- `sessionId` muda quando `configure` ou `startNewSession` inicia uma sessão.
- `eventId` é único dentro da sessão.
- `sequenceNumber` é estritamente crescente e define a ordem. Timestamps
  iguais não afetam a ordenação.
- `timestampMicros` usa relógio de parede de `DateTime.now()`, em
  microssegundos desde Unix epoch.
- `ObserverNodeId` vem de contador monotônico local ao processo. Label,
  `hashCode` público, valor e timestamp nunca são identidade.

`Observable`, `Computed`, `ReactiveScope` e `Worker` expõem sua identidade
estável. `Observer`, `watch(context)` e effects usam internamente o mesmo ID
durante todo o lifecycle.

## Eventos

Lifecycle de nós:

- `NodeCreatedEvent`
- `NodeUpdatedEvent`
- `NodeDisposedEvent`

Execução rastreada e mudanças no grafo:

- `TrackerRunStartedEvent`
- `DependenciesChangedEvent`
- `TrackerRunFinishedEvent`

Ownership de scopes:

- `ScopeCreatedEvent`
- `ScopeResourceRegisteredEvent`
- `ProtocolScopeDisposedEvent`

Diagnóstico:

- `WarningRaisedEvent`

O fim do tracker é emitido em um caminho `finally`. Se o callback lança,
`completedWithError` é verdadeiro e a exceção original continua seguindo o
comportamento existente de propagação/relato.

`DependenciesChangedEvent` contém o conjunto final completo e os conjuntos
adicionado/removido. Leituras repetidas são deduplicadas. Quando uma condição
deixa de ler um nó, o ID aparece em `removedDependencyIds`.

## Registry e snapshot

`ObserverProtocol.snapshot()` retorna metadados imutáveis de:

- nós ativos;
- dependências ativas dos trackers;
- scopes ativos e recursos registrados;
- última sequência representada;
- eventos descartados e limites disponíveis do buffer.

O registry armazena IDs, kinds, labels, nomes de tipo, timestamps e resumos
seguros. Não retém objetos do usuário nem valores arbitrários crus. Nós/scopes
descartados e suas arestas são removidos. Um consumer registrado depois da
criação pode solicitar snapshot e aplicar eventos cujo `sequenceNumber` seja
maior que `snapshot.lastSequenceNumber`.

Iniciar nova sessão limpa registry e buffer. Objetos anteriores à nova sessão
não são redescobertos automaticamente até que uma versão futura defina um
contrato explícito de re-registro.

## Ring buffer e eventos descartados

O buffer é limitado e remove o evento mais antigo quando cheio.
`droppedEventCount` contabiliza remoções. Tamanho zero ainda despacha para
inspectors conectados, mas não retém eventos; cada evento incrementa o
contador. `firstAvailableSequence` e `lastAvailableSequence` descrevem a
janela retida.

## Segurança de valores

Valores crus nunca são armazenados. Com `captureValues: false`, o resumo tem
somente o tipo. Com captura ativa:

- `null`, booleanos, números, enums e strings limitadas podem ter exibição;
- strings com aparência sensível são redigidas;
- strings longas são truncadas em `maxStringLength`;
- listas, mapas, sets e `Uint8List` expõem apenas tipo e tamanho;
- objetos arbitrários nunca passam por `toString()` nem são percorridos.

A aplicação pode fornecer `redactValue` em `ObserverProtocolConfig` para
forçar a redação conforme sua própria política. Se esse callback lançar, o
protocolo falha de forma segura, redige o valor e não interrompe a atualização
reativa.

Isso torna o resumo seguro para referências circulares e para `toString()`
lento, que lança ou que produz texto enorme. Stack traces são opt-in separado
e permanecem desativados por padrão.

## Modelo de overhead

Desativado, o protocolo retorna cedo antes de criar eventos, resumir valores,
mutar registry, capturar stack ou escrever no buffer. Nós ainda recebem uma
identidade monotônica barata para que `objectId` seja estável independentemente
do momento em que o diagnóstico é ativado. Ativado, o custo corresponde apenas
aos recursos configurados.

## Limites

O protocolo não é um detector de leaks. A ausência de `dispose()` não prova
vazamento. A versão 1 não possui rotas/telas, UI do Flutter DevTools, transporte
VM Service, rede, ações remotas, edição de valor cru ou correlação automática
com widgets fora dos trackers instrumentados.

`ObservableList`, `ObservableMap` e `ObservableSet` ainda usam a inspeção
legada na versão 1 e não aparecem como nós independentes do protocolo. Iniciar
uma nova sessão também não redescobre automaticamente objetos criados em uma
sessão anterior.
