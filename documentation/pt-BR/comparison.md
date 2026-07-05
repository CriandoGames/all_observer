🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/comparison.md) | 🇧🇷 Português

# Como o `all_observer` se compara

Uma comparação factual e não-promocional contra outras abordagens de
reatividade em Flutter/Dart. Nenhuma delas é "ruim" — resolvem para
prioridades diferentes. Afirmações sobre outras bibliotecas aqui se
limitam ao que está documentado nos próprios docs oficiais delas; na
dúvida, o texto permanece genérico em vez de específico.

| | `all_observer` | GetX | Riverpod | Bloc | MobX | signals |
|---|---|---|---|---|---|---|
| Dependências externas | Zero | Zero (ela própria é tudo-em-um) | `riverpod`, geralmente `flutter_riverpod`/`riverpod_generator` | `bloc`, `flutter_bloc` | `mobx`, `mobx_codegen`, `build_runner` | Zero |
| Code generation | Nenhum | Nenhum | Opcional (`riverpod_generator`), comum na prática | Nenhum | Obrigatório (`build_runner`) para `@observable`/`@computed`/`@action` | Nenhum |
| Injeção de dependência | Nenhuma (componha com a sua) | Embutida (`Get.put`/`Get.find`) | Embutida (grafo de providers) | Nenhuma (componha com a sua) | Nenhuma | Nenhuma |
| Roteamento | Nenhum | Embutido (`Get.to`, rotas nomeadas) | Nenhum | Nenhum | Nenhum | Nenhum |
| Escopo | Só valores reativos + rebuild de widgets | Estado + rotas + DI + snackbars/dialogs (framework completo) | Estado + DI (grafo de providers), sem helpers de rota/UI | Arquitetura de eventos/estado (padrão BLoC) | Valores reativos + actions/reactions, sem DI/rotas | Só reatividade, multiplataforma (não é Flutter-específico) |
| Rastreamento de dependência | Automático (leitura de `.value` durante build/`effect()`/`Computed`) | Automático, via `Obx`/`GetX` lendo `.value`/`.obs` | Automático, via `ref.watch` dentro de um `Provider`/`Notifier` | Manual (eventos explícitos → transições de estado) | Automático, via `Observer`/reactions lendo campos `@observable` | Automático, via leitura de signal dentro de um effect/computed |
| Primitivas assíncronas | `ObservableFuture`/`ObservableStream` (seguro contra corrida, contador de geração) | `.obs` + tratamento assíncrono manual | `FutureProvider`/`StreamProvider` | Handlers assíncronos de evento (`on<Event>` com `emit`) | Reactions sobre actions assíncronas | Depende dos bindings de plataforma |
| Glitches de dependência em diamante | Prevenidos por design (flush em duas fases, `ARCHITECTURE.md`) | Não é uma garantia documentada | N/A (providers não formam um grafo encadeado tipo `Computed` da mesma forma) | N/A (máquina de estados, não um grafo de dependência) | Prevenidos pelo próprio núcleo reativo do MobX | Prevenidos por design (seu principal diferencial) |
| Testabilidade | Objetos Dart comuns, sem widget para a maioria dos testes | `Get.testMode`, testes de widget para `Obx` | `ProviderContainer` para testes unitários | Bem estabelecida (`bloc_test`, `blocTest`) | Objetos reativos comuns, testável em unidade | Objetos comuns, testável em unidade |
| Curva de aprendizado | Baixa | Baixa | Média | Média–alta | Média | Baixa |
| Tamanho da API | Pequeno (`Observable`, `Observer`, `Computed`, workers, async, coleções) | Grande (estado+DI+rotas+utilitários) | Médio–grande (providers, notifiers, modifiers) | Médio (eventos, estados, bloc/cubit) | Médio (observables, actions, reactions, codegen) | Pequeno |

## GetX

Um framework tudo-em-um: gerenciamento de estado, injeção de dependência e
roteamento em um único pacote com quase nenhum boilerplate. Melhor escolha
quando você quer uma única biblioteca dona de toda a arquitetura do app e
está confortável com suas convenções. `all_observer` cobre só a fatia de
estado reativo do que o GetX faz — veja
[migration_from_getx.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/migration_from_getx.md)
se você está saindo da camada de estado do GetX enquanto mantém (ou
substitui separadamente) seu DI/roteamento.

## Riverpod

Um grafo de providers verificado em tempo de compilação, com uma boa
história de DI e sem dependência de `BuildContext` para ler estado.
Melhor escolha quando você quer que o compilador capture um provider
faltando/mal configurado antes do runtime, e não se importa com a
cerimônia de declaração de providers (e, na maioria dos projetos reais,
um gerador de código). `all_observer` não tem grafo de providers nem
camada de DI alguma — você compõe com o que já usa.

## Bloc

Uma arquitetura explícita e auditável de evento → estado, popular em
times maiores que valorizam uma separação estrita entre "o que aconteceu"
(eventos) e "o que a UI mostra" (estados), mais ferramentas de teste de
primeira classe (`bloc_test`). Melhor escolha quando auditabilidade e um
fluxo unidirecional estrito importam mais do que minimizar boilerplate.
`all_observer` não tem camada de eventos — mudanças de estado são
escritas diretas de valor, não eventos despachados.

## MobX

Um núcleo reativo maduro baseado em decorators (`@observable`,
`@computed`, `@action`) com suas próprias dev tools, exigindo codegen via
`build_runner`. Melhor escolha se você já está investido nesse
vocabulário e etapa de codegen, ou quer suas ferramentas de rastreamento
de actions/reactions. `all_observer` busca o mesmo tipo de rastreamento
automático de dependências sem nenhuma etapa de geração de código.

## signals

O parente filosófico mais próximo: reatividade sem dependências e livre
de glitch, com uma API pequena. `signals` é Dart multiplataforma (não é
Flutter-específico) com uma extensão de DevTools para navegador em seu
ecossistema. `all_observer` é Flutter-first (com
`package:all_observer/core.dart` como sua própria válvula de escape em
Dart puro) e traz um widget `Observer`, coleções reativas, e primitivas
assíncronas seguras contra corrida prontas no mesmo pacote.

## Por que escolher `all_observer`

Use quando você quer estado reativo e nada mais: nenhum container de DI
para aprender, nenhuma convenção de roteamento para adotar, nenhum gerador
de código no seu pipeline de build, e nenhum risco de uma dependência
transitiva ficar desatualizada ou sem manutenção, porque não existe
nenhuma. A mesma primitiva escala de um único contador até um grafo de
`Computed`, estado assíncrono seguro contra corrida, e observabilidade
plugável, sem trocar de vocabulário no meio do caminho. Ela compõe com
(em vez de substituir) o roteamento/DI do GetX, o grafo de providers do
Riverpod, a arquitetura de eventos do Bloc, ou uma classe controller
feita à mão, já que `all_observer` não tem opinião sobre onde o estado
*vive* — só sobre como ele *notifica*.

Escolha outra coisa quando precisar especificamente do que ela faz de
melhor: o pacote tudo-em-um de rotas+DI+estado do GetX se quiser um
framework para tudo; o Riverpod se quiser um grafo de DI verificado em
tempo de compilação; o Bloc se seu time valoriza uma arquitetura de
evento/estado auditável em escala; o MobX se já estiver investido em seu
vocabulário de action/reaction; o `signals` se precisar do mesmo modelo
reativo fora do Flutter por completo.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Testes](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md) · Próximo: [Migrando do GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/migration_from_getx.md)
