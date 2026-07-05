🇧🇷 Português | 🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/testing.md)

# Testes

`Observable`, `Computed`, e todo worker (`ever`/`once`/`debounce`/
`interval`) são objetos Dart puros — sem wrapper de `Provider`/`Bloc`/DI,
sem framework de mocking, sem geração de código. Eles se testam do mesmo
jeito que qualquer objeto Dart: construa, mute, faça asserções, com
`flutter_test` de fábrica. Todo exemplo desta página é um teste real que
roda no CI, dentro de
[`example/test/`](https://github.com/CriandoGames/all_observer/tree/main/example/test)
— nenhum dos trechos abaixo é pseudocódigo ilustrativo.

## Testes de widget (widget tests)

O formato básico: dê `pumpWidget` no widget sob teste, mute o observável
que ele lê, `pump()`, faça a asserção. Nenhum wrapper/escopo é necessário
além do shell Material que os próprios widgets exigirem — diferente de
`Provider`/`Bloc`, não há `ChangeNotifierProvider`/`BlocProvider` para
configurar antes.

```dart
final CounterController controller = CounterController();
addTearDown(controller.dispose);

await tester.pumpWidget(
  MaterialApp(home: Scaffold(body: CounterDemo(controller: controller))),
);
expect(find.text('Count: 0'), findsOneWidget);

controller.increment();
await tester.pump(); // <- obrigatório: veja o alerta abaixo
expect(find.text('Count: 1'), findsOneWidget);
```

Arquivo completo:
[`counter_widget_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/counter_widget_test.dart).

> **A pegadinha do `pump()`.** Atribuir um novo valor nunca repinta nada por
> si só. O `Observer` agrupa seu rebuild para o próximo frame, exatamente
> como o `ValueListenableBuilder` — é preciso `await tester.pump()` (ou
> `pumpAndSettle()`) após uma mutação antes de fazer asserções sobre a
> árvore de widgets.

## Testes unitários (Dart puro)

Testes de controller/lógica de negócio não precisam de nenhum binding do
Flutter: sem `testWidgets`, sem `pumpWidget`. `Observable`/`Computed` são
construídos e lidos como qualquer outro objeto Dart.

```dart
late CounterController controller;

setUp(() => controller = CounterController());
tearDown(() => controller.dispose());

test('mutar count recalcula o valor derivado do Computed', () {
  controller.increment();
  expect(controller.count.value, 1);
  expect(controller.doubled.value, 2);
});
```

Arquivo completo:
[`controller_unit_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/controller_unit_test.dart).
Note o `tearDown` chamando `dispose()`/`close()` em todo observável que o
controller possui — o hábito correto a levar para seus próprios testes,
espelhando `State.dispose()` no widget real.

## Provando o rebuild granular

O rebuild granular é a alegação central do `all_observer`, e é diretamente
mensurável: dê a dois `Observer`s um contador de builds cada, faça-os ler
observáveis diferentes, mute um deles, e verifique que só o contador
correspondente se moveu.

```dart
final ObservableInt a = 0.obs;
final ObservableInt b = 0.obs;
int buildsA = 0;
int buildsB = 0;
// ... Observer(() { buildsA++; return Text('a:${a.value}'); }) ...
// ... Observer(() { buildsB++; return Text('b:${b.value}'); }) ...

a.value = 1;
await tester.pump();
expect(buildsA, 2); // reconstruiu
expect(buildsB, 1); // intocado
```

Arquivo completo:
[`observer_granularity_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/observer_granularity_test.dart).
Use esta técnica sempre que precisar verificar que uma refatoração não
ampliou acidentalmente do que um `Observer` depende.

## Testando workers e tempo

`debounce`/`interval` são testados com o relógio virtual do
`flutter_test`: `tester.pump(Duration(...))` avança o tempo falso dentro de
um corpo `testWidgets`, então workers baseados em timer resolvem de forma
determinística em vez de correr contra uma `Duration` real. Esta é a mesma
abordagem que a própria suíte do pacote usa
(`test/workers/workers_test.dart`) — nenhuma dependência extra de
`fake_async` é necessária para testar workers baseados em tempo.

```dart
controller.query.setValue('a');
await tester.pump(const Duration(milliseconds: 50));
controller.query.setValue('apr');
expect(controller.searchRuns.value, 1); // ainda dentro da janela de debounce

await tester.pump(const Duration(milliseconds: 250));
expect(controller.searchRuns.value, 2); // exatamente uma busca real rodou
```

Arquivo completo:
[`worker_debounce_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/worker_debounce_test.dart).

## Testando estado assíncrono

`ObservableFuture` é testado injetando uma fábrica de `Future` falsa através
do construtor — o mesmo padrão de "dependência via construtor" aplicado ao
trabalho assíncrono — usando um `Completer` controlado manualmente em vez de
um atraso real de rede/timer.

```dart
final Completer<int> completer = Completer<int>();
final FetchController controller = FetchController(
  fetcher: () => completer.future,
);

expect(controller.fetch.value, isA<AsyncLoading<int>>());
completer.complete(42);
await Future<void>.delayed(Duration.zero);
expect(controller.fetch.value, const AsyncData<int>(42));
```

Arquivo completo:
[`observable_future_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/observable_future_test.dart).
Como o `Completer` só resolve quando o teste chama `complete`/
`completeError`, as transições loading → data e loading → error acontecem
em um ponto exato que o teste controla — nada aqui espera um timer real,
então o teste não pode ficar instável (flaky).

## Strict mode nos testes

`ObserverConfig.strictMode` transforma dois erros comuns — um `Observer`
que não lê nenhum observável, e uma escrita em um observável durante o
build de um `Observer` — em um `ObserverError` lançado em vez de um warning
de console que um log de CI poderia deixar passar despercebido.

```dart
setUp(() => ObserverConfig.strictMode = true);
tearDown(ObserverConfig.reset);

testWidgets('um Observer que não lê nada lança', (tester) async {
  await tester.pumpWidget(MaterialApp(home: Observer(() => const Text('x'))));
  expect(tester.takeException(), isA<ObserverError>());
});
```

Arquivo completo:
[`strict_mode_test.dart`](https://github.com/CriandoGames/all_observer/blob/main/example/test/strict_mode_test.dart).
Sempre combine `strictMode = true` no `setUp` com `ObserverConfig.reset()`
no `tearDown`, para que não vaze para testes não relacionados na mesma
suíte.

## Arquitetura testável recomendada

O app de exemplo extrai a lógica de negócio do `State` para pequenas
classes de controller
([`example/lib/controllers/`](https://github.com/CriandoGames/all_observer/tree/main/example/lib/controllers)),
cada uma construível com uma dependência injetável e um padrão sensato:

```dart
class FetchController {
  FetchController({Future<int> Function()? fetcher})
    : fetch = ObservableFuture<int>(fetcher ?? _simulateFetch);
  // ...
}
```

O widget cria um controller padrão internamente quando nenhum é passado,
então os pontos de uso em produção (`const AsyncDemo()`) continuam simples,
enquanto um teste pode injetar um fake:

```dart
AsyncDemo(controller: FetchController(fetcher: () => completer.future));
```

Este é o padrão a adotar sempre que o estado de um widget for difícil de
testar por ter sido construído sem ponto de injeção — extraia-o para uma
classe Dart simples que recebe suas dependências pelo construtor, com um
padrão que preserva os pontos de uso atuais sem alteração.

## Checklist

- Chame `await tester.pump()` (ou `pumpAndSettle()`) após toda mutação
  antes de fazer asserções sobre a árvore de widgets — uma escrita sozinha
  não repinta nada.
- Chame `close()`/`dispose()` em todo `Observable`/`Computed`/`Worker`/
  controller que você possui no `tearDown`, espelhando `State.dispose()`.
- Injete dependências assíncronas/de tempo pelo construtor (uma função de
  busca, um catálogo, uma `Duration` de debounce) em vez de fixá-las no
  código, para que os testes possam substituir por fakes.
- Prefira o relógio virtual do `flutter_test` (`tester.pump(duration)`) em
  vez de `Duration`s reais para qualquer coisa com debounce/throttle.
- Use um `Completer` para controlar exatamente quando uma `Future` injetada
  resolve, em vez de correr contra um atraso real.
- Ative `ObserverConfig.strictMode` (resetado no `tearDown`) em testes/CI
  para capturar erros de `Observer` vazio e escrita durante build como
  falhas.
- Lógica de negócio (qualquer coisa que não leia `BuildContext`) pertence a
  uma classe Dart simples, testável sem nenhum binding de widget.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Avançado](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md) · Próximo: [Comparação](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/comparison.md)
