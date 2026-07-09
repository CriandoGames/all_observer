🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/async.md) | 🇧🇷 Português

# Estado assíncrono

`ObservableFuture<T>`, `ObservableStream<T>`, e o `AsyncState<T>` (alias
`AsyncValue<T>`) sobre o qual são construídos — estado de
carregando/dados/erro assíncrono e seguro contra corrida, sem nenhum
maquinário de `Stream` exigido de você.

## `AsyncState<T>`

Uma union sealed simples com três casos: `AsyncLoading<T>`, `AsyncData<T>`,
`AsyncError<T>`. Consuma com `when`/`maybeWhen`, ou os getters
`isLoading`/`hasData`/`hasError`/`valueOrNull`:

```dart
state.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (value) => Text('$value'),
  error: (error, stackTrace) => Text('Erro: $error'),
);
```

`AsyncLoading.previousData` opcionalmente carrega o último valor
conhecido de `AsyncData` — uma leitura do tipo stale-while-loading, para
que uma UI possa continuar mostrando o conteúdo anterior (esmaecido,
sobreposto) em vez de um spinner em branco durante um refresh.

## `ObservableFuture<T>`

Um `Observable<AsyncState<T>>` que executa uma `Future<T> Function()` e
rastreia seu ciclo de vida automaticamente:

```dart
final userFuture = ObservableFuture<User>(() => api.fetchUser(id));

Observer(() => userFuture.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (user) => Text(user.name),
  error: (error, stackTrace) => Text('Erro: $error'),
));

userFuture.refresh(); // re-executa futureFactory, ex.: para pull-to-refresh
```

`autoStart: true` por padrão — a future roda imediatamente na construção.
Passe `autoStart: false` para construir sem iniciar, e chame `run()`
manualmente quando estiver pronto:

```dart
final searchFuture = ObservableFuture<List<Result>>(
  () => api.search(query),
  autoStart: false,
);
// depois, quando o usuário submeter:
searchFuture.run();
```

`refresh()` é só um alias mais expressivo para `run()` — ambos reinvocam
`futureFactory`.

### Segurança contra corrida

Toda chamada a `run()`/`refresh()` incrementa um contador interno de
geração. Se `futureFactory` for invocado novamente (um `run` mais novo)
antes de uma chamada anterior terminar, o resultado dessa chamada mais
antiga — sucesso ou erro — é silenciosamente descartado quando chegar, em
vez de sobrescrever o estado mais novo. A mesma proteção descarta um
resultado ainda em andamento se `close()` tiver sido chamado nesse meio
tempo. Isso significa que refreshes rápidos repetidos (um usuário
clicando várias vezes em "tentar de novo", ou uma busca digitada rápido)
nunca mostram um resultado desatualizado ultrapassando um mais recente.

## `ObservableStream<T>`

O equivalente em `Stream`, com o mesmo contrato de `AsyncState`:

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

Todo evento da stream vira uma atualização `AsyncData`; um erro da stream
vira `AsyncError`. `refresh()` cancela a assinatura atual e inicia uma
nova a partir de `streamFactory` — útil para reconectar uma stream de
socket/polling depois de um erro. A segurança contra corrida funciona da
mesma forma que em `ObservableFuture` (contador de geração), mais o
cancelamento explícito da `StreamSubscription` anterior antes de assinar
de novo, então uma assinatura obsoleta para de receber eventos por
completo em vez de depender só da checagem de geração.

Se `streamFactory()` lançar uma exceção sincronamente antes de retornar uma
`Stream`, `run()` a converte em `AsyncError`, mantendo o mesmo contrato de
falha de `ObservableFuture`. Falhas assíncronas retornadas por
`StreamSubscription.cancel()` são isoladas e encaminhadas por
`CoreErrorReporting`, sem gerar erro assíncrono não tratado.

## Padrão de pull-to-refresh

```dart
RefreshIndicator(
  onRefresh: () => userFuture.refresh(),
  child: Observer(() => userFuture.value.when(
    loading: (previousData) => previousData != null
        ? UserCard(user: previousData, dimmed: true)
        : const CircularProgressIndicator(),
    data: (user) => UserCard(user: user),
    error: (error, stackTrace) => ErrorView(error: error),
  )),
);
```

Usar `previousData` durante o `loading` mantém o último conteúdo conhecido
visível (esmaecido) enquanto um refresh está em andamento, em vez de
piscar um spinner sobre conteúdo já carregado.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Coleções](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md) · Próximo: [Workers](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/workers.md)
