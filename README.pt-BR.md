# all_observer

🇬🇧 [Read in English](README.md)

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
<a href="https://pub.dev/packages/all_observer/score"><img src="https://img.shields.io/pub/points/all_observer?label=pub%20points" alt="pub points"></a>
 <img src="https://img.shields.io/badge/testes-225-brightgreen" alt="225 testes"> <!-- atualizar ao adicionar testes -->


Estado reativo para Flutter, sem dependências. Valores `Observable` mais um
widget `Observer` com auto-rastreamento — um núcleo pequeno, seguro e sem
dependências para apps que querem reatividade sem um framework completo de
gerenciamento de estado.

## Por que `all_observer`

- **Zero dependências.** Todo o núcleo reativo — rastreamento,
  notificação, coleções, workers — é construído só com `Dart`/`Flutter`.
  Nenhum `Stream`, nenhuma geração de código, nenhum pacote externo para
  manter sincronizado com sua versão do Flutter.
- **Sem boilerplate.** Nenhum provider para registrar, nenhum context para
  conectar, nenhuma classe base para estender. `final count = 0.obs;` mais
  `Observer(() => ...)` já é um par reativo completo e funcional.
- **Granular por construção.** As dependências são descobertas *lendo*
  `.value` durante um build, não declaradas antecipadamente, então um
  `Observer` só reconstrói pelo que ele realmente lê — inclusive em
  ramos condicionais (`if (a) lê x senão lê y`), que são reavaliados
  corretamente a cada build.
- **Seguro por padrão.** Rebuilds são protegidos contra widgets
  desmontados, um ciclo de atualização síncrono (A → B → A) para em vez de
  estourar a pilha, uma exceção dentro de um listener nunca impede os
  demais de rodar, e todo caso de mau uso (`Observer` vazio, escrita
  durante o build, escrita após `close()`) emite warning em vez de
  derrubar o app — com um `strictMode` opcional que transforma esses
  mesmos warnings em falhas duras para CI.
- **Interoperável, não um jardim murado.** `Observable<T>` *é* um
  `ValueListenable<T>`, então se encaixa direto em `ValueListenableBuilder`,
  `AnimatedBuilder`, `Listenable.merge`, ou qualquer API do Flutter que já
  entenda essa interface.

### Quando usar

Apps e features pequenas a médias que querem estado reativo local/global
— contadores, campos de formulário, flags de loading, uma lista/cache
reativa, um resumo calculado — sem adotar uma arquitetura completa
(plumbing de evento/estado estilo BLoC, providers gerados por código
etc.). Também funciona bem *junto* de uma arquitetura maior, como a
primitiva reativa por baixo de uma view-model ou classe controller.

### Quando algo mais pode encaixar melhor

Se você precisa de injeção de dependência, escopo de estado por rota, ou
grafos de providers verificados em tempo de compilação, um framework
dedicado de DI/estado vai te dar mais estrutura do que este pacote
propositalmente oferece. `all_observer` não tem opinião sobre onde seu
estado *mora* — só sobre como ele *notifica* — então ele compõe com esses
frameworks em vez de substituí-los (ex.: envolva um `Observable` dentro de
um provider/service que você já gerencia).

## Começando em 30 segundos

```dart
import 'package:all_observer/all_observer.dart';

final count = 0.obs; // ObservableInt

Observer(() => Text('${count.value}'));

count.value++; // reconstrói o Text acima, e somente ele
```

Crie observáveis a partir de qualquer tipo com `.obs`: `0.obs`, `'oi'.obs`,
`false.obs`, `9.99.obs`, `<String>[].obs`, ou envolva um tipo próprio com
`Observable<User?>(null, name: 'user')`. Leia `.value` dentro do builder de
um `Observer` e o widget reconstrói automaticamente sempre que ele mudar —
as dependências são redescobertas a cada build, então leituras condicionais
funcionam sem esforço extra.

## Interoperabilidade com `ValueListenable`

Todo `Observable<T>` implementa `ValueListenable<T>`, então ele se encaixa
diretamente em qualquer coisa que já fale essa interface — sem adaptador:

```dart
ValueListenableBuilder<int>(
  valueListenable: count, // um Observable<int> funciona diretamente aqui
  builder: (context, value, _) => Text('$value'),
);

AnimatedBuilder(animation: Listenable.merge([count, outroObservavel]), ...);
```

## Valores derivados com `Computed`

```dart
final firstName = 'Carlos'.obs;
final lastName = 'Castro'.obs;
final fullName = Computed(() => '${firstName.value} ${lastName.value}');

Observer(() => Text(fullName.value)); // recalcula só quando necessário
```

`Computed<T>` é preguiçoso (nunca roda antes da primeira leitura),
memoizado (fica em cache até uma dependência notificar), reaproveita o
mesmo mecanismo de rastreamento do `Observer` (então dependências
condicionais/dinâmicas funcionam da mesma forma) e só notifica seus
próprios listeners quando o valor recalculado realmente difere do
anterior. Chame `close()` para cancelar a inscrição em todas as
dependências atuais.

Para um valor derivado mais estreito a partir de um único `Observable`,
`select` é açúcar sintático sobre o mesmo padrão: `user.select((u) =>
u.name)` é exatamente `Computed(() => user.value.name)`. Quem chama é dono
do `Computed` retornado e deve chamar `close()` nele.

### `equals` customizado no `Computed`

```dart
final fahrenheit = Computed<double>(
  () => celsius.value * 9 / 5 + 32,
  equals: (a, b) => (a - b).abs() < 0.01,
);
```

Assim como `Observable`, `Computed` aceita um `equals` customizado para
decidir se um valor recalculado realmente mudou e deve notificar — útil
para tolerâncias de ponto flutuante ou comparações parciais de campos.

### Grafos de dependência em diamante e `batch`

Um "diamante" é quando dois `Computed` derivam da mesma origem, e um
terceiro depende de ambos. Envolva as escritas que alimentam esse grafo em
`Observable.batch()`: o recompute de qualquer `Computed` do grafo é adiado
até que toda escrita do batch tenha se estabilizado, então ele recalcula
no máximo uma vez, sempre a partir de valores a montante totalmente
consistentes. Veja "Limitações conhecidas" abaixo para o que acontece sem
`batch`.

## Agrupando escritas com `Observable.batch`

```dart
Observable.batch(() {
  firstName.value = 'Carlos';
  lastName.value = 'Castro';
  age.value = 30;
}); // listeners manuais (listen()/ever()) disparam uma única vez, no fim
```

As escritas ainda se aplicam imediatamente e de forma consistente dentro
do callback — apenas a *notificação* para assinantes manuais (`listen`,
`ever`, etc.) é adiada e deduplicada. Um widget `Observer` já agrupa
múltiplas mudanças de dependência em um único rebuild por frame por conta
própria, então `batch()` importa principalmente para subscrições manuais.
Chamadas `batch()` aninhadas são suportadas; se o callback lançar uma
exceção, as notificações pendentes construídas até então são descartadas
e a exceção se propaga normalmente.

## Igualdade customizada com `equals`

```dart
final price = Observable<double>(
  9.99,
  equals: (a, b) => (a - b).abs() < 0.01,
);
```

Por padrão, uma escrita só notifica quando o novo valor difere do atual
via `==`. Passe `equals` para usar uma comparação diferente — por exemplo,
uma tolerância para valores de ponto flutuante, ou comparar apenas parte
de um objeto maior.

## Coleções reativas

```dart
final items = <String>[].obs; // ObservableList<String>

Observer(() => Text('${items.length} itens'));

items.add('um');                 // notifica uma vez
items.addAll(['dois', 'três']);  // ainda uma vez, não três
items.removeWhere((e) => e == 'dois'); // uma vez, e só se algo combinou
```

`ObservableList`/`ObservableMap`/`ObservableSet` se comportam como suas
contrapartes nativas (`ListBase`/`MapBase`/`SetBase`) para toda leitura —
`length`, `[]`, `contains`, iteração — enquanto todo membro mutante
notifica **no máximo uma vez por chamada**, nunca uma vez por elemento.
Uma mutação sem efeito (adicionar um elemento de `Set` que já existe,
`removeWhere` que não combina com nada, atribuir um valor idêntico a uma
chave já existente do map) notifica zero vezes.

## Valores assíncronos com `ObservableFuture`

```dart
final userFuture = ObservableFuture<User>(() => api.fetchUser(id));

Observer(() => userFuture.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (user) => Text(user.name),
  error: (error, stackTrace) => Text('Erro: $error'),
));

userFuture.refresh(); // reexecuta a future, ex.: pull-to-refresh
```

`ObservableFuture<T>` é um `Observable<AsyncState<T>>` que executa uma
`Future<T> Function()` e acompanha automaticamente seu ciclo de vida de
carregando/dados/erro (`autoStart: true` por padrão; passe `false` e chame
`run()` manualmente caso contrário). `AsyncLoading.previousData` carrega o
último valor conhecido enquanto um `refresh()` está em andamento, para UIs
do tipo stale-while-loading. Toda chamada a `run()`/`refresh()` é segura
contra corrida: se uma chamada mais nova iniciar antes de uma mais antiga
resolver, o resultado da mais antiga (sucesso ou erro) é descartado quando
chegar, e qualquer resultado ainda em andamento também é descartado se
`close()` tiver sido chamado nesse meio tempo.

## Além do `Observer`: effects, streams, inspeção e helpers de lifecycle

Um conjunto de blocos menores e independentes — cada um opcional, nenhum
muda o grafo reativo central.

### Reatividade autônoma com `effect()`

```dart
final dispose = effect(() {
  print('contador agora é ${count.value}');
});
// ...
dispose(); // para de reagir
```

`effect()` roda imediatamente e de novo sempre que qualquer observável que
ele lê mudar — o mesmo auto-rastreamento do `Observer`, sem um widget. Útil
fora da árvore de widgets (uma classe controller, um listener em segundo
plano).

### Escapatórias: `untracked()`, `peek()`, `previousValue`

```dart
final resultado = untracked(() => a.value + b.value); // lê sem rastrear
final atual = contador.peek(); // lê sem rastrear, forma mais curta
final anterior = contador.previousValue; // valor logo antes da última mudança
```

`untracked()` lê observáveis dentro do callback sem registrá-los como
dependências de qualquer `Observer`/`Computed`/`effect()` que esteja
rastreando no momento — útil para uma leitura avulsa que não deveria causar
rebuild por conta própria. `Observable.peek()` é açúcar sintático para a
mesma coisa em um único valor; `previousValue` olha para o valor de antes
da atualização mais recente, sem nenhuma configuração extra para habilitar.

### Observabilidade plugável com `ObserverInspector`

```dart
final recorder = RecordingInspector();
ObserverConfig.inspectors.add(recorder);
// ... depois
for (final event in recorder.events) {
  print(event); // ObservableCreateEvent, ObservableUpdateEvent, ...
}
```

Todo evento de criação/atualização/descarte/rastreamento/warning/execução
-de-effect é exposto através da interface `ObserverInspector`, não apenas
impresso no console. O clássico log colorido no terminal é ele mesmo uma
implementação formal — `ConsoleInspector` — registrada internamente por
padrão; `RecordingInspector` vem incluído como uma trilha de auditoria em
memória. Escreva o seu próprio para encaminhar eventos a analytics, um sink
de log próprio, ou um overlay de debug — uma exceção lançada por um
inspector nunca bloqueia os demais.

### `ObservableStream`, o equivalente em `Stream` do `ObservableFuture`

```dart
final ticks = ObservableStream<int>(
  () => Stream.periodic(const Duration(seconds: 1), (i) => i),
);
Observer(() => ticks.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (n) => Text('$n'),
  error: (error, stackTrace) => Text('Erro: $error'),
));
```

Mesmo contrato de `AsyncState`/carregando-dados-erro do `ObservableFuture`,
conduzido por uma `Stream` no lugar: todo evento vira `AsyncData`, um erro
da stream vira `AsyncError`, e `refresh()` cancela a assinatura atual e
inicia uma nova — seguro contra corrida pelo mesmo contador de geração.

### `ObserverStateMixin`, para efeitos colaterais ligados ao tempo de vida de um `State`

```dart
class _MyPageState extends State<MyPage> with ObserverStateMixin {
  @override
  void initState() {
    super.initState();
    autorun(() {
      if (session.value.isExpired) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    });
  }
}
```

`autorun` é um `effect()` descartado automaticamente com o `State`;
`autoDispose` aceita qualquer `Disposer` (o `.cancel` de uma subscrição, o
`.close` de um `Computed`, ...). Isto é para efeitos colaterais que não
pertencem ao `build()` — navegação, snackbars, conduzir um
`AnimationController` — não um substituto do `Observer`.

### Persistência opcional com `ObservableStore`

```dart
final theme = Observable<String>('light');
final stop = theme.persistWith(minhaThemeStore); // minhaThemeStore: ObservableStore<String>
// ...
stop(); // para de persistir; `theme` continua funcionando normalmente
```

`ObservableStore<T>` é uma interface de três métodos (`read`/`write`/
`delete`) sem nenhuma implementação incluída aqui — o `all_observer`
permanece livre de dependências. Um pacote ponte (ex.:
[`all_box`](https://pub.dev/packages/all_box)) pode implementá-la contra
armazenamento real; `persistWith` restaura uma vez na vinculação e escreve
de volta a cada mudança subsequente.

### Desfazer/refazer limitado com `ObservableHistory`

```dart
final texto = Observable<String>('');
final history = texto.withHistory(limit: 50);
texto.value = 'olá';
texto.value = 'olá mundo';
history.undo(); // texto.value == 'olá'
history.undo(); // texto.value == ''
history.redo(); // texto.value == 'olá'
history.dispose();
```

Registra toda mudança de valor, ignora mudanças feitas pelo próprio
`undo()`/`redo()` (para que refazer depois de desfazer restaure o valor
exato, em vez de criar um novo ramo), e descarta as entradas mais antigas
assim que `limit` é excedido.

### `package:all_observer/core.dart` — o motor puro-Dart, sem Flutter

```dart
import 'package:all_observer/core.dart';

final contador = CoreObservable<int>(0);
contador.addListener(() => print('agora $contador.value'));
contador.value = 1;
```

O rastreador de dependências, o registro de listeners, o motor de batch/
flush e os tipos de observabilidade têm **zero import de
`package:flutter`** e são re-exportados por este ponto de entrada separado
— utilizável em uma ferramenta de linha de comando, um servidor, ou um
isolate em segundo plano, não só em um app Flutter. `Observable`/`Computed`
(de `all_observer.dart`) são wrappers finos de `ValueListenable` + logging
no console sobre `CoreObservable`/`CoreComputed` — mesmo motor, mesmo
comportamento, Flutter adicionado por cima.

## Rebuilds mais granulares com `Observer.withChild`

```dart
Observer.withChild(
  builder: (context, child) => Row(
    children: [Text('${count.value}'), child],
  ),
  child: const WidgetEstaticoCaro(),
);
```

Uma subárvore filha estática, uma técnica comum para evitar reconstruções
de widgets caros que não dependem de nenhum observável: `child` é
construído uma vez e repassado de volta para `builder` a cada rebuild, em
vez de ser reconstruído.

## `setValue`, uma forma inequívoca de atribuir `null`

```dart
final name = Observable<String?>('Carlos');
name.setValue(null); // atribui null e notifica
```

`call()` trata um argumento `null` como "nenhum argumento" (para suportar
a forma de leitura sem argumento `observable()`), então `observable(null)`
lê em vez de atribuir. `setValue(newValue)` é equivalente a `value =
newValue` e atribui `null` sem ambiguidade; também é útil como tear-off
(ex.: diretamente como um callback `onChanged`).

## Estado local e autocontido com `ObserverValue`

```dart
ObserverValue<ObservableInt>(
  (data) => ElevatedButton(
    onPressed: () => data.value++,
    child: Text('${data.value}'),
  ),
  0.obs,
);
```

Uma camada fina sobre o `Observer` para estado que é criado e consumido
bem onde é usado: passe o observável, receba-o de volta dentro do
`builder` a cada rebuild — sem variável separada declarada acima do
widget, sem `Observer(() => ...)` explícito por fora.

## Efeitos colaterais com workers

```dart
final query = ''.obs;
final estaLogado = false.obs;
final contador = 0.obs;
final scrollOffset = 0.0.obs;

// Roda 400ms depois da última mudança — perfeito para busca ao digitar.
final debounceWorker = debounce(query, (String valor) {
  rodarBusca(valor);
}, time: const Duration(milliseconds: 400));

// Roda uma única vez, depois se descarta automaticamente.
once(estaLogado, (bool valor) {
  if (valor) analytics.logLogin();
});

// Roda a cada mudança, como um listener manual com um nome mais amigável.
final everWorker = ever(contador, (int valor) => print('contador agora é $valor'));

// Roda no máximo uma vez por `time`, imediatamente na primeira mudança.
final intervalWorker = interval(scrollOffset, (double valor) {
  salvarPosicaoDoScroll(valor);
}, time: const Duration(seconds: 1));

// Descarte os que você guardou referência quando terminar:
Workers([debounceWorker, everWorker, intervalWorker]).dispose();
```

Workers são a forma recomendada de rodar efeitos colaterais fora de
widgets (chamadas de rede, analytics, persistência) a partir de uma
mudança em um observável, em vez de espalhar chamadas manuais a
`addListener`. `once` se descarta sozinho depois de disparar;
`debounce`/`interval` cancelam seu `Timer` interno no `dispose()`, então
nada dispara depois que você termina com eles.

## Logs de debug coloridos

Habilite `ObserverConfig.logging = true` durante o desenvolvimento para ver
a reatividade acontecendo no terminal, colorida por tipo de evento:

| Evento | Cor |
|---|---|
| ✚ criação | verde |
| ↻ atualização de valor | ciano (valores em magenta) |
| 👁 rastreamento do Observer | azul |
| ✖ descarte | cinza |
| ⚠ warning de mau uso | amarelo negrito |

```
[all_observer] ✚ Observable<int>(count) criado → 0
[all_observer] ↻ Observable<int>(count): 0 → 1
[all_observer] 👁 Observer(contador) rastreando: [count, isLoading]
[all_observer] ✖ Observable<int>(count) descartado (2 listeners removidos)
```

Defina `ObserverConfig.useColors = false` em terminais sem suporte a ANSI.
Warnings de mau uso (um `Observer` que não lê nada, escrita após `close()`,
escrita durante o build, provável vazamento de listeners) vêm habilitados
por padrão via `ObserverConfig.warnings` e nunca derrubam o app — defina
`strictMode = true` para transformar o caso de "Observer vazio" em exceção,
útil em CI/testes.

## Decisões de design

As reconstruções são protegidas contra widgets já desmontados: o callback
interno verifica `mounted` antes de agendar trabalho, e adia para o
próximo frame em vez de usar um microtask puro quando a mudança acontece
no meio do build. Builders reativos aninhados são suportados corretamente
através de um rastreador de dependências baseado em pilha, em vez de um
único "contexto atual" mutável que o rastreamento aninhado poderia
sobrescrever. A semântica de notificação é uma regra única e previsível —
uma escrita só notifica se o novo valor for diferente do atual — sem
tratamento especial para a primeira atribuição; objetos mutáveis alterados
no próprio lugar podem forçar uma notificação via `refresh()`. A igualdade
(`==`/`hashCode`) nunca é sobrescrita no wrapper reativo, então as
comparações sempre significam o que dizem: compare `.value` explicitamente.
O núcleo não tem nenhum `Stream` ou `StreamController` internamente —
`listen()` é construído diretamente sobre um registro leve de listeners,
mantendo o núcleo reativo pequeno. E, em vez de lançar exceções em erros
prováveis, o pacote prefere warnings amigáveis e não fatais por padrão,
com um modo estrito opcional para times que querem falhas duras em CI.

## Mais

- `ObservableList`, `ObservableMap`, `ObservableSet`: coleções reativas; ler qualquer membro rastreia, mutar qualquer membro notifica exatamente uma vez por chamada (operações em lote como `addAll`/`removeWhere`/`retainWhere` nunca notificam por elemento).
- `Computed<T>`: valores derivados preguiçosos e memoizados, construídos sobre o mesmo rastreador de dependências do `Observer`, com `equals` customizável e mitigação do glitch do diamante ciente de batch.
- `ObservableFuture<T>` / `ObservableStream<T>` / `AsyncState<T>` (com alias `AsyncValue<T>`): estado assíncrono de carregando/dados/erro, seguro contra corrida, construído sobre `Observable`, conduzido por uma `Future` ou uma `Stream`.
- `effect()` / `untracked()` / `Observable.peek()` / `Observable.previousValue`: reatividade autônoma e escapatórias de rastreamento.
- `ObserverInspector` / `ConsoleInspector` / `RecordingInspector`: observabilidade plugável para todo evento de lifecycle/atualização/warning.
- `ObserverStateMixin`: `effect()`s e subscrições manuais descartados automaticamente, ligados ao tempo de vida de um `State`.
- `ObservableStore<T>` / `Observable.persistWith`: ponto de integração opcional para persistência (ex.: `all_box`), sem adicionar dependência.
- `ObservableHistory<T>` / `Observable.withHistory`: desfazer/refazer limitado para qualquer `Observable`.
- `package:all_observer/core.dart`: o motor puro-Dart (`CoreObservable`, `CoreComputed`, `DependencyTracker`, ...), zero import de `package:flutter`, utilizável fora do Flutter.
- `Observable.batch`: agrupa múltiplas escritas em uma única notificação por observável alterado, para assinantes manuais.
- `Observer.withChild`: reconstrói apenas a parte de uma subárvore que pertence ao builder, reaproveitando um `child` estático entre rebuilds.
- `Observable.select`: açúcar sintático para um `Computed` mais estreito derivado de um único `Observable`.
- `ObserverValue<T>`: estado reativo local e autocontido, sem gerenciar o ciclo de vida de um observável separadamente.
- `ever`, `once`, `debounce`, `interval`: workers para efeitos colaterais disparados por mudanças em observáveis.
- Um ciclo de atualização síncrono (o listener de A escreve em B, o de B escreve em A, ...) é interrompido após uma profundidade de notificação limitada, com um erro descritivo, em vez de um stack overflow bruto; uma exceção lançada dentro de um listener nunca impede que os demais listeners do mesmo observável rodem.
- Veja `/example` para uma demonstração executável (contador, lista reativa, worker, alternador de logs de debug), e `/benchmark` para microbenchmarks manuais baseados em Stopwatch.

## Como o `all_observer` se compara

Uma comparação factual, sem tom de marketing, contra outras abordagens de
reatividade em Flutter/Dart — o que cada uma exige que o `all_observer`
não exige, e vice-versa. Nenhuma delas é "ruim"; cada uma resolve para
prioridades diferentes.

| | `all_observer` | GetX | Riverpod | MobX | flutter_hooks |
|---|---|---|---|---|---|
| Dependências externas | **Zero** | Zero (ela mesma é tudo-em-um) | `riverpod`, geralmente `flutter_riverpod`/`riverpod_generator` | `mobx`, `mobx_codegen`, `build_runner` | `flutter_hooks` |
| Geração de código | Nenhuma | Nenhuma | Opcional (`riverpod_generator`), comum na prática | Obrigatória (`build_runner`) para `@observable`/`@computed`/`@action` | Nenhuma |
| Escopo | Só valores reativos + rebuild de widget | Estado + rotas + DI + snackbars/diálogos (um framework completo) | Estado + DI (grafo de providers), sem helpers de rota/UI | Valores reativos + actions/reactions, sem DI/rotas | Estado/lifecycle composável local ao widget, sem store entre widgets |
| Rastreamento de dependências | Automático (ler `.value` durante build/`effect()`/`Computed`) | Automático, via `Obx`/`GetX` lendo `.value`/`.obs` | Automático, via `ref.watch` dentro de um `Provider`/`Notifier` | Automático, via `Observer`/reactions lendo campos `@observable` | N/A (hooks são locais ao widget, não um grafo de dependências) |
| Glitches em dependências de diamante | Prevenidos por design (`ADR-0001`/`ADR-0002` no `ARCHITECTURE.md`) | Não é uma garantia documentada | N/A (providers não formam um grafo estilo `Computed` da mesma forma) | Prevenidos pelo próprio núcleo reativo do MobX | N/A |
| Interoperabilidade com `ValueListenable` | Direta — `Observable<T>` *é* um | Não | Não | Não | Não |
| Escapatórias | `untracked()`, `.peek()`, `.previousValue` | Leituras de `.value` fora de `Obx` já não rastreiam | `ref.read` (leitura não rastreada) | `mobx.untracked` | N/A |
| Observabilidade | `ObserverInspector` plugável (`ConsoleInspector`, `RecordingInspector`, ou o seu próprio) | Logging via `Get.log` | `ProviderObserver` | Dev-tools do MobX / Spy API | N/A |
| Utilizável fora do Flutter | Sim — `package:all_observer/core.dart`, zero import de Flutter | Não | Sim (o núcleo do `riverpod` tem uma variante não-Flutter) | Sim (o núcleo do `mobx` é puro Dart) | Não (só Flutter, por design) |
| Comportamento em caso de mau uso | Warning amigável por padrão, `strictMode` opcional lança exceção | Varia pela superfície de API | Grafo de providers verificado em tempo de compilação pega algumas classes de erro mais cedo | Warnings em tempo de execução no modo dev | Tempo de compilação (regras de hook impostas por lint) |

### Por que escolher o `all_observer`

Use quando você quer estado reativo e nada mais: nenhum container de DI
para aprender, nenhuma convenção de rotas para adotar, nenhum gerador de
código no seu pipeline de build, e nenhum risco de uma dependência
transitiva ficar desatualizada ou sem manutenção, porque não existe
nenhuma. `final count = 0.obs;` mais `Observer(() => Text('${count.value}'))`
é o modelo mental inteiro — a mesma primitiva escala de um contador único
até um grafo de `Computed`, estado assíncrono seguro contra corrida, e
observabilidade plugável, sem trocar de vocabulário no meio do caminho.
Compõe com (em vez de substituir) as rotas/DI do GetX, o grafo de
providers do Riverpod, ou uma classe controller feita à mão, já que o
`all_observer` não tem opinião sobre onde o estado *mora* — só sobre como
ele *notifica*.

Use outra coisa quando você precisar especificamente do que aquela outra
coisa faz de melhor: o GetX tudo-em-um de rotas+DI+estado se você quer um
único framework para tudo; o Riverpod se você quer um grafo de DI
verificado em tempo de compilação e não se importa com a cerimônia de
declarar providers; o MobX se você já está investido no vocabulário de
actions/reactions dele e no passo de codegen; o `flutter_hooks` se seu
estado é genuinamente local ao widget e você quer composição estilo
`useState`/`useEffect` em vez de um valor autônomo.

## Migrando de outras soluções de estado reativo

`all_observer` cobre os mesmos conceitos centrais que a maioria das
abordagens de estado reativo cobre, sob nomes próprios. Este é um mapa
conceito a conceito, não uma portabilidade nome a nome de nenhuma
biblioteca específica:

| Conceito | `all_observer` |
|---|---|
| Valor reativo estilo Rx | `Observable<T>` (`.obs` para criar um) |
| Widget builder reativo com auto-rastreamento de dependências | `Observer` |
| Valor reativo derivado/calculado | `Computed<T>` |
| Helpers de efeito colateral em mudança de valor (`ever`/`once`/`debounce`/`interval`) | Mesmos nomes: `ever`, `once`, `debounce`, `interval` |
| Estado assíncrono de carregando/dados/erro | `ObservableFuture<T>` / `AsyncState<T>` |
| Escritas agrupadas/transacionais | `Observable.batch(() { ... })` |
| Dispose / encerramento | `close()` em todo `Observable`/`Computed`/coleção |

O que **não** tem equivalente aqui, por design — `all_observer` cuida
apenas da *reatividade*, não da arquitetura do app:

- **Roteamento / navegação**: use o próprio `Navigator`/`Router` do
  Flutter, ou um pacote de roteamento dedicado.
- **Snackbars / diálogos / overlays**: use o próprio `ScaffoldMessenger`,
  `showDialog`, `showModalBottomSheet` etc. do Flutter diretamente —
  `all_observer` não tem uma camada de efeito colateral de UI para
  conectar a esses.
- **Injeção de dependência / localização de serviços**: traga sua própria
  solução de DI (um singleton simples passado por construtor, um
  `InheritedWidget`, ou um pacote de DI dedicado) e guarde `Observable`s
  dentro dos serviços/controllers que ela gerencia — `all_observer` não
  tem opinião sobre onde o estado *mora*, só sobre como ele *notifica*.

## Limitações conhecidas

- **`Observable.batch()` é uma otimização de desempenho, não um requisito de
  consistência.** Desde a v1.2.0, toda escrita — mesmo um `observable.value = x`
  avulso, fora de qualquer `batch()` explícito — é automaticamente roteada pelo
  mesmo flush em duas fases que `batch()` usa. Grafos de dependências em
  diamante (`Computed` A e B derivados da mesma fonte S, `Computed` C
  dependendo de A e B) sempre recalculam exatamente uma vez, sempre a partir
  de valores a montante totalmente estabilizados — sem glitch, sem `batch()`
  necessário. Envolver múltiplas escritas em `batch()` continua sendo útil
  para coalescer notificações: todas as escritas no callback são confirmadas
  primeiro, e então os listeners são notificados uma vez por observável
  alterado, em vez de uma vez por escrita.
- **`Computed` permanece inscrito após a primeira leitura, até `close()`.**
  Ler `.value` (ou anexar um listener) faz um `Computed` se inscrever
  indefinidamente em suas dependências atuais — ele não se desinscreve
  sozinho só porque ninguém mais está escutando. Chame `close()` quando
  terminar com um `Computed` criado manualmente (os de vida curta, ex.: a
  partir de `select`, são fáceis de esquecer).
- **Confinamento a um único isolate.** Como o restante do Dart, todo
  `Observable`/`Computed`/coleção é confinado ao isolate que o criou; não
  há sincronização entre isolates. Use `SendPort`/`ReceivePort` ou
  `compute` para mover dados entre isolates e escreva de volta no
  observável no seu próprio isolate.

## Outras libs nossas

`all_observer` faz parte de uma pequena família de pacotes Dart & Flutter
com zero ou poucas dependências, publicados sob o publisher verificado
[`opensource.tatamemaster.com.br`](https://pub.dev/publishers/opensource.tatamemaster.com.br/packages):

- [`all_validations_br`](https://pub.dev/packages/all_validations_br) —
  validação de documentos brasileiros (CPF, CNPJ, CNH, PIX), 23
  formatadores/máscaras de input, e utilitários puro-Dart (JWT, UUID,
  moeda, criptografia ChaCha20-Poly1305/AES).
- [`all_box`](https://pub.dev/packages/all_box) — armazenamento
  chave-valor síncrono e leve para Flutter, com escritas à prova de
  crash (write-ahead + rename atômico) e uma camada reativa
  pure-Flutter.
- [`all_image_compress`](https://pub.dev/packages/all_image_compress) —
  compressão de imagem puro-Dart (JPEG, PNG, GIF, BMP, TIFF, WebP),
  rodando em isolates para não travar a UI, sem código nativo.

## 👥 Contribuidores

[![Contributors](https://contrib.rocks/image?repo=CriandoGames/all_observer)](https://github.com/CriandoGames/all_observer/graphs/contributors)

Made with [contrib.rocks](https://contrib.rocks).

Contribuições são bem-vindas! Leia o [CONTRIBUTING.md](CONTRIBUTING.md) para
começar.

---

Issues e pull requests são bem-vindos no
[repositório do GitHub](https://github.com/CriandoGames/all_observer).
