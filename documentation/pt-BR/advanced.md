🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/advanced.md) | 🇧🇷 Português

# Avançado

`batch`, dependências em diamante, `equals`/`setValue`, logging/`strictMode`,
decisões de design, limitações conhecidas, testes — mais os blocos de
construção opcionais menores (`effect`, `untracked`, `watch(context)`,
`ReactiveScope`, inspectors, helpers de lifecycle, `core.dart`).

## `Observable.batch`

```dart
Observable.batch(() {
  firstName.value = 'Carlos';
  lastName.value = 'Castro';
  age.value = 30;
}); // listeners manuais de listen()/ever() disparam exatamente uma vez, no final
```

As escritas ainda se aplicam imediatamente e de forma consistente dentro do
callback — só a *notificação* para assinantes manuais (`listen`, `ever`,
etc.) é adiada e deduplicada. Um widget `Observer` já agrupa múltiplas
mudanças de dependência em um único rebuild por frame por conta própria,
então `batch()` importa principalmente para assinaturas manuais. Chamadas
aninhadas de `batch()` são suportadas (só a mais externa libera o flush);
se o callback lançar, as notificações pendentes acumuladas até então são
descartadas e a exceção se propaga normalmente.

## Dependências em diamante

Um "diamante" é dois `Computed`s ambos derivados da mesma fonte, com um
terceiro dependendo de ambos (`a -> b, a -> c, [b, c] -> d`).

Desde a v1.2.0, `Observable.batch()` é uma **otimização de performance,
não um requisito de consistência**. Toda escrita — mesmo um
`observable.value = x` isolado fora de qualquer `batch()` explícito — é
automaticamente roteada pelo mesmo flush em duas fases que `batch()` usa.
Grafos em diamante sempre recalculam exatamente uma vez, sempre a partir
de valores upstream totalmente estabilizados — sem glitch, sem `batch()`
necessário.

Envolver múltiplas escritas em `batch()` continua útil para *agrupar*
notificações: todas as escritas do callback são commitadas primeiro, e só
então os listeners são notificados uma vez por observável alterado, em vez
de uma vez por escrita. Veja a seção "two-phase flush" do
`ARCHITECTURE.md` para o mecanismo exato (duas filas drenadas em ondas de
ponto fixo, limitadas por `kMaxFlushWaves`).

## `setValue` — uma forma inequívoca de atribuir `null`

```dart
final name = Observable<String?>('Carlos');
name.setValue(null); // atribui null e notifica
```

`call()` trata um argumento `null` como "nenhum argumento" (para suportar
a forma de leitura sem argumento `observable()`), então
`observable(null)` lê o valor atual em vez de atribuir `null`.
`setValue(newValue)` é equivalente a `value = newValue` e atribui `null`
sem ambiguidade; também é útil como tear-off (ex.: diretamente como
callback `onChanged`).

## `equals` customizado

Tanto `Observable` quanto `Computed` aceitam uma sobrescrita de `equals`
para decidir se uma escrita/recálculo realmente mudou e deve notificar:

```dart
final fahrenheit = Computed<double>(
  () => celsius.value * 9 / 5 + 32,
  equals: (a, b) => (a - b).abs() < 0.01,
);
```

Útil para tolerâncias de ponto flutuante ou comparações parciais em
objetos maiores.

## `ObserverConfig`: logging, warnings, `strictMode`

```dart
ObserverConfig.logging = true; // saída colorida no terminal
```

```
[all_observer] ✚ Observable<int>(count) criado → 0
[all_observer] ↻ Observable<int>(count): 0 → 1
[all_observer] 👁 Observer(contador) rastreando: [count, isLoading]
[all_observer] ✖ Observable<int>(count) descartado (2 listeners removidos)
```

| Evento | Cor |
|---|---|
| ✚ criação | verde |
| ↻ atualização de valor | ciano (valores em magenta) |
| 👁 rastreamento do Observer | azul |
| ✖ descarte | cinza |
| ⚠ warning de mau uso | amarelo em negrito |

- `ObserverConfig.useColors = false` — desative as cores ANSI em terminais
  sem suporte.
- `ObserverConfig.logLevel` — `all` (padrão), `updates`, `lifecycle`, ou
  `tracking`, para restringir quais categorias imprimem.
- `ObserverConfig.warnings` (padrão `true`) — warnings de mau uso: um
  `Observer` que não lê nada, uma escrita após `close()`, uma escrita
  durante o build, um provável vazamento de listener
  (`listenerLeakThreshold`, padrão 50). Nunca quebra o app por conta
  própria.
- `ObserverConfig.strictMode` (padrão `false`) — transforma os casos
  "Observer vazio" e "escrita durante o build" em um `ObserverError`
  lançado em vez de um warning. Ative isso em CI/testes para transformar
  esses enganos em falhas duras.
- `ObserverConfig.reset()` — restaura todas as configurações para o
  padrão; útil entre testes.

Todo logging é exclusivo de debug: em builds de release (`kReleaseMode`)
as chamadas são eliminadas na compilação independentemente dessas flags.

## Observabilidade plugável: `ObserverInspector`

```dart
final recorder = RecordingInspector();
ObserverConfig.inspectors.add(recorder);
// ... depois
for (final event in recorder.events) {
  print(event); // ObservableCreateEvent, ObservableUpdateEvent, ...
}
```

Todo evento de criação/atualização/descarte/rastreamento/warning/execução-
de-effect/descarte-de-escopo é exposto através da interface
`ObserverInspector` (`onCreate`/`onUpdate`/`onDispose`/`onTrack`/
`onWarning`/`onEffectRun`/`onScopeDispose`), não só impresso no console. `ConsoleInspector` — a clássica saída colorida do
terminal — é ela própria uma implementação formal, chamada direta e
incondicionalmente para que registrar seus próprios inspectors nunca
duplique, silencie ou reordene ela. `RecordingInspector` vem como um
buffer circular em memória (padrão 1000 eventos) para asserções sobre
comportamento em testes ou para construir um overlay de debug. Uma
exceção lançada por um inspector nunca bloqueia os demais. Defina
`ObserverConfig.captureStackTraces = true` para anexar um `StackTrace` a
cada evento (desligado por padrão — capturar um a cada evento não é
gratuito).

## Reatividade autônoma com `effect()`

```dart
final dispose = effect(() {
  print('count agora é ${count.value}');
});
// ...
dispose(); // para de reagir
```

Roda imediatamente, depois roda de novo sempre que qualquer observável
lido durante sua execução anterior mudar — o mesmo auto-tracking que o
`Observer` usa, sem widget ou `BuildContext`. Útil fora da árvore de
widgets (uma classe controller, um listener em background). Workers
(`ever`/`once`/`debounce`/`interval`) continuam sendo a ferramenta certa
para o caso comum de um único observável; `effect` é para callbacks que
leem mais de um observável, ou cujas dependências mudam condicionalmente
entre execuções.

Prefira manter escritas em métodos de controller ou workers, não dentro de
um `effect()` que também lê o mesmo grafo. Quando um effect escreve
intencionalmente em um observável depois de ler um valor derivado, o
all_observer agrupa essa autoinvalidação durante o mesmo flush de batch: o
effect não roda uma passada compensatória duplicada, e escritas externas
posteriores continuam agendando normalmente. Use `untracked()` ou `.peek()`
para leituras que só servem para decidir o que escrever e não devem virar
dependências.

## Rebuilds cirúrgicos com `watch(context)`

```dart
class CounterLabel extends StatelessWidget {
  const CounterLabel({super.key});

  @override
  Widget build(BuildContext context) {
    // Sem wrapper Observer: este element se inscreve sozinho.
    return Text('${count.watch(context)}');
  }
}
```

`observable.watch(context)` (também disponível em `Computed`) lê o valor e
inscreve o próprio `Element` do widget chamador: quando o observável muda,
apenas aquele element reconstrói. É a semântica do `Observer` na
granularidade do widget chamador, sem widget wrapper na árvore — útil
quando um `build()` inteiro é, na prática, uma única expressão reativa.

Todo o resto funciona como o `Observer`: as dependências são redescobertas
a cada build (`watch`es condicionais em observáveis diferentes por
passagem funcionam naturalmente), vários observáveis observados pelo mesmo
element se agrupam em um único rebuild por batch/frame, e uma mudança que
chega durante build/layout/paint adia o rebuild para um callback pós-frame
em vez de lançar exceção. Dentro de um builder de `Observer` (ou de um
`Computed`/`effect`), o `watch` apenas reporta a leitura àquele rastreador
ativo e *não* inscreve também o element — sem inscrição dupla.

**Limpeza preguiçosa — o único trade-off a conhecer.** O `Element` do
Flutter não expõe gancho de unmount para pacotes, então uma assinatura
feita por `watch` pode sobreviver ao seu element até a *primeira
notificação após o unmount*: nesse ponto ela é um no-op garantido (nada
reconstrói, nada lança) e todas as assinaturas daquele element são
liberadas. Na prática: no máximo uma notificação extra ignorada por
observável, nunca um rebuild de widget morto. O caso extremo é um
observável que *nunca mais muda* — o listener inerte dele continua
anexado. Se esse padrão importar no seu app (um observável global de vida
longa lido por muitas telas de vida curta), prefira o `Observer`, cujo
`dispose()` limpa avidamente.

Em builds de debug, chamar `watch` fora do `build()` registra um warning —
e lança um `ObserverError` sob `ObserverConfig.strictMode` — já que a
assinatura não acompanharia o ciclo de rebuild do element.

## Limpeza escopada com `ReactiveScope`

```dart
final scope = ReactiveScope(name: 'CounterController');

scope.run(() {
  total = Computed(() => a.value + b.value);   // registrado no scope
  effect(() => print(total.value));             // registrado no scope
  ever(a, (_) => save());                       // registrado no scope
});

scope.dispose(); // fecha o Computed, cancela o effect e o worker
```

Todo `Computed`, `effect()` e worker (`ever`/`once`/`debounce`/`interval`)
criado dentro de `scope.run(...)` registra seu próprio disposer no escopo,
então uma única chamada a `dispose()` derruba tudo — em ordem inversa de
criação (LIFO), e de forma idempotente. Ele vive no core em Dart puro
(`package:all_observer/core.dart` também o exporta), então controllers sem
nenhum import de Flutter podem usá-lo. Tudo é opt-in: criados fora de
qualquer `run()`, os recursos se comportam exatamente como antes — você é
dono do descarte deles.

Detalhes que valem conhecer: escopos aninham (um escopo construído dentro
do `run()` de um pai é descartado com o pai; descartar o filho nunca afeta
o pai); `scope.add(disposer)` registra qualquer outra coisa manualmente
(um `ObservableSubscription.cancel`, um `ObservableFuture.close`, ...);
registrar em um escopo já descartado roda o disposer imediatamente (nunca
vaza) mais um warning de debug — ou um `ObserverError` sob `strictMode`; e
cada descarte despacha um evento `ObserverInspector.onScopeDispose`.
`Observable`s simples deliberadamente **não** são capturados: eles não
possuem recurso que precise ser liberado — `close()` só limpa listeners, e
listeners pertencem aos seus consumidores
(`Observer`/`Computed`/`effect`/workers), que o escopo já cobre. Registre
um manualmente via `scope.add(obs.close)` se quiser a proteção de
escrita-após-close.

Para o caso comum de "classe controller", o `ScopedObserverMixin` empacota
isso com a mesma ergonomia que o `ObserverStateMixin` tem para `State`s:

```dart
class CounterController with ScopedObserverMixin {
  final a = 1.obs;
  final b = 2.obs;

  late final total = scoped(() => Computed(() => a.value + b.value));

  CounterController() {
    scoped(() => ever(a, (_) => save()));
    autoDispose(someSubscription.cancel); // registro manual
  }

  void close() => disposeScope();
}
```

## Escape hatches: `untracked()`, `.peek()`, `.previousValue`

```dart
final result = untracked(() => a.value + b.value); // lê sem rastrear
final current = counter.peek();       // atalho para o mesmo, valor único
final before = counter.previousValue; // valor antes da última mudança
```

`untracked()` lê observáveis dentro de seu callback sem registrá-los como
dependências do que quer que `Observer`/`Computed`/`effect()` esteja
rastreando no momento — útil para uma leitura pontual que não deveria
causar um rebuild por conta própria. `previousValue` só é atualizado por
uma mudança de valor de fato (não por `refresh()`, já que o valor em si
não mudou).

## `ObserverStateMixin`: efeitos colaterais ligados ao ciclo de vida

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

`autorun` é um `effect()` autodescartado junto com o `State`;
`autoDispose` aceita qualquer `Disposer` (o `.cancel` de uma subscrição, o
`.close` de um `Computed`, ...). Isso é para efeitos colaterais que não
pertencem ao `build()` — navegação, snackbars, conduzir um
`AnimationController` — não um substituto do `Observer`. Todo disposer
registrado roda exatamente uma vez, em ordem inversa de registro (LIFO).
Desde a 1.4.0 este mixin roda sobre um `ReactiveScope` interno (o mesmo
motor do `ScopedObserverMixin`, ver a seção de limpeza escopada acima) —
um refactor interno, mesma API pública.

## Persistência opcional com `ObservableStore`

```dart
final theme = Observable<String>('light');
final stop = theme.persistWith(myThemeStore); // myThemeStore: ObservableStore<String>
// ...
stop(); // para de persistir; `theme` continua funcionando normalmente
```

`ObservableStore<T>` é uma interface de três métodos (`read`/`write`/
`delete`) sem implementação fornecida aqui — `all_observer` continua
livre de dependências. Um pacote-ponte (ex.:
[`all_box`](https://pub.dev/packages/all_box)) pode implementá-la contra
armazenamento real; `persistWith` restaura uma vez ao vincular e escreve
de volta a cada mudança subsequente.

## Desfazer/refazer limitado com `ObservableHistory`

```dart
final text = Observable<String>('');
final history = text.withHistory(limit: 50);
text.value = 'hello';
text.value = 'hello world';
history.undo(); // text.value == 'hello'
history.undo(); // text.value == ''
history.redo(); // text.value == 'hello'
history.dispose();
```

Registra toda mudança de valor, ignora mudanças feitas pelo próprio
`undo()`/`redo()` (para que refazer depois de desfazer restaure exatamente
o valor desfeito, em vez de criar um novo branch), e descarta as entradas
mais antigas assim que `limit` é excedido. Independente do `Observable`
que envolve — descartar o histórico não fecha o observável subjacente.

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

Uma conveniência fina sobre `Observer` para estado que é criado e
consumido bem onde é usado: passe o observável, receba-o de volta dentro
de `builder` a cada rebuild — sem variável separada para declarar acima do
widget.

## `package:all_observer/core.dart` — o motor em Dart puro

```dart
import 'package:all_observer/core.dart';

final counter = CoreObservable<int>(0);
counter.addListener(() => print('agora ${counter.value}'));
counter.value = 1;
```

O rastreador de dependências, o registro de listeners, o motor de
batch/flush e os tipos de observabilidade têm **zero import de
`package:flutter`** e são reexportados através deste ponto de entrada
separado — utilizável a partir de uma ferramenta CLI, um servidor, ou um
isolate em background, não só um app Flutter. `Observable`/`Computed` (de
`all_observer.dart`) são wrappers finos de `ValueListenable` + logging no
console sobre `CoreObservable`/`CoreComputed` — mesmo motor, mesmo
comportamento, com Flutter adicionado por cima.

## Decisões de design

Rebuilds são protegidos contra widgets já desmontados: o callback interno
checa `mounted` antes de agendar trabalho, e adia para o próximo frame em
vez de um microtask cru quando uma mudança acontece durante o build.
Builders reativos aninhados são suportados corretamente através de um
rastreador de dependências baseado em pilha, em vez de um único "contexto
atual" mutável que o rastreamento aninhado poderia corromper. A semântica
de notificação é uma única regra previsível — uma escrita só notifica se
o novo valor difere do atual — sem tratamento especial para a primeira
atribuição; objetos mutáveis alterados no próprio lugar podem forçar uma
notificação via `refresh()`. A igualdade (`==`/`hashCode`) nunca é
sobrescrita no wrapper reativo, então comparações sempre significam o que
dizem: compare `.value` explicitamente. O núcleo não tem `Stream` ou
`StreamController` dentro dele — `listen()` é construído diretamente
sobre um registro leve de listeners, mantendo o núcleo reativo pequeno. E
em vez de lançar exceções em enganos prováveis, o pacote favorece
warnings amigáveis e não fatais por padrão, com um modo estrito opcional
para times que querem falhas duras em CI.

Dois guardas de ciclo independentes existem para duas formas diferentes de
atualização descontrolada: `kMaxNotificationDepth` limita a profundidade
recursiva da pilha de chamadas para ciclos fora de qualquer batch (o
listener de A escreve em B, o listener de B escreve em A); `kMaxFlushWaves`
limita a contagem iterativa de ondas para a mesma forma de ciclo
acontecendo dentro de um batch. Ambos abortam com um `ObserverCycleError`
descritivo em vez de um stack overflow cru ou um loop infinito.

## Limitações conhecidas

- **`Observable.batch()` é uma otimização de performance, não um
  requisito de consistência.** Veja a seção de dependências em diamante
  acima — toda escrita já é livre de glitch sem ele.
- **`Computed` continua inscrito após sua primeira leitura, até
  `close()`.** Ler `.value` (ou anexar um listener) faz um `Computed` se
  inscrever em suas dependências atuais indefinidamente — ele não se
  desinscreve sozinho só porque ninguém mais está escutando. Chame
  `close()` quando terminar de usar um `Computed` criado manualmente (os
  de vida curta, ex.: de `select`, são fáceis de esquecer) — ou crie-o
  dentro de um `ReactiveScope`/`ScopedObserverMixin` (ver acima) para que
  o `dispose()` do escopo o feche por você.
- **Confinamento a um único isolate.** Como o restante do Dart, todo
  `Observable`/`Computed`/coleção é confinado ao isolate que o criou; não
  há sincronização entre isolates. Use `SendPort`/`ReceivePort` ou
  `compute` para mover dados entre isolates e escrever de volta no
  observável no seu próprio isolate.

## Testes

`all_observer` não exige nenhum harness de teste especial —
`Observable`s e `Computed`s são objetos Dart comuns que você pode
ler/escrever/afirmar diretamente em `flutter_test`/`test`, sem precisar de
`pumpWidget` a menos que esteja testando um `Observer`/widget de fato.

- Ative `ObserverConfig.strictMode = true` no `setUp` de um teste (e chame
  `ObserverConfig.reset()` no `tearDown`) para capturar um `Observer`
  acidentalmente vazio ou uma escrita durante o build como um erro
  lançado em vez de um warning no console que você pode não notar.
- Teste um `Computed` lendo `.value` diretamente e fazendo asserções
  depois de mudar suas dependências — sem widget necessário.
- Teste workers (`ever`/`once`/`debounce`/`interval`) com `fakeAsync` ou
  `FakeAsync`/`tester.pump(duration)` do `flutter_test` para controlar
  timers deterministicamente em vez de `Duration`s reais.
- Use `RecordingInspector` (registrado via `ObserverConfig.inspectors`)
  para afirmar sobre a sequência exata de eventos de
  criação/atualização/descarte que um trecho de código produziu, quando
  uma asserção simples de valor não for precisa o suficiente.
- A suíte do próprio pacote fica em `/test`, organizada por área
  (`observable/`, `widgets/`, `workers/`, `async/`, `core/`, `effects/`,
  `engine/`, `regressions/`) — uma referência útil para padrões de teste
  contra esta API.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Workers](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/workers.md) · Próximo: [Testes](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md)
