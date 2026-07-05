🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/faq.md) | 🇧🇷 Português

# FAQ

## Preciso chamar `close()` em todo observável?

Para qualquer coisa que você cria manualmente e guarda como campo (um
`Observable`, `Computed`, `ObservableList`/`Map`/`Set`,
`ObservableFuture`/`Stream`, `ObservableHistory`), sim — chame
`close()`/`dispose()` quando terminar de usá-lo, tipicamente em
`State.dispose()`. `Computed` em particular fica inscrito em suas
dependências indefinidamente até ser fechado (ver
[Limitações conhecidas](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md)).
Widgets `Observer`/`ObserverValue` limpam suas próprias inscrições de
rastreamento automaticamente quando desmontados — você não precisa
gerenciar essas.

## Por que meu `Observer` não reconstrói?

As duas causas mais comuns:

1. **Você leu o observável fora do builder.** Só leituras que acontecem
   *durante* a chamada de `builder()` do `Observer` são rastreadas — ler
   `.value` antes de construir o `Observer`, ou guardá-lo em uma variável
   local calculada fora do builder, não conta.
2. **Você mutou um objeto no próprio lugar sem chamar `refresh()`.** Se o
   observável guarda um objeto mutável e você mudou um campo dele
   diretamente (em vez de atribuir um novo valor), o `==` vê a mesma
   referência e não notifica — chame `refresh()` depois da mutação.

Um `Observer` que não lê nada também gera um warning de debug ("nunca vai
reconstruir") para ajudar a capturar esse tipo de engano cedo.

## Posso usar `all_observer` junto com Provider/Riverpod/Bloc?

Sim. `all_observer` não tem registro global e nenhuma opinião sobre onde
seu estado vive — envolva um `Observable` dentro de um
`Provider`/`Notifier`/`Bloc` que você já gerencia, ou use-o de forma
autônoma ao lado deles. Ele compõe em vez de competir.

## Funciona em Web/desktop?

Sim — o núcleo reativo não tem código específico de plataforma. `Observer`
é um `StatefulWidget` comum, então funciona em qualquer lugar que widgets
Flutter funcionem.

## Como testo código que usa `all_observer`?

`Observable`/`Computed` são objetos Dart comuns — leia/escreva/afirme
diretamente em `test`/`flutter_test`, sem `pumpWidget` necessário a menos
que você esteja testando um `Observer` de fato. Veja o guia dedicado de
[Testes](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md)
para testes de widget, testes unitários, `strictMode` e dicas de teste de
workers/async — todo exemplo lá é um teste real de
[`example/test/`](https://github.com/CriandoGames/all_observer/tree/main/example/test).

## Qual a diferença entre `Observer` e `ValueListenableBuilder`?

`Observable<T>` *é* um `ValueListenable<T>`, então `ValueListenableBuilder`
funciona diretamente com ele — mas só rastreia o único `valueListenable`
que você passa. `Observer` descobre automaticamente *todo* observável lido
dentro de seu builder, incluindo vários de uma vez e leituras
condicionais/dinâmicas, sem precisar declará-los previamente.

## `batch()` é obrigatório?

Não. Desde a v1.2.0, toda escrita já é automaticamente livre de glitch —
grafos de dependência em diamante recalculam corretamente sem ele.
`batch()` continua útil puramente para *agrupar* notificações a
assinantes manuais (`listen`/`ever`) quando você escreve em vários
observáveis em uma única ação lógica. Ver
[Avançado](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md).

## É pronto para produção? Quantos testes tem?

225 testes na v1.3.0, cobrindo o rastreador de dependências do núcleo,
cenários de diamante/ciclo do `Computed`, o contrato de notificar-no-
-máximo-uma-vez das coleções, segurança contra corrida assíncrona,
workers, e o sistema de logging/inspector de debug. Veja
`ARCHITECTURE.md` na raiz do repositório para a fundamentação do design
por trás da garantia de ser livre de glitch especificamente.

## O que acontece se uma exceção for lançada dentro de um listener/effect/inspector?

Ela é isolada: uma exceção lançada por um listener nunca impede que outros
listeners do mesmo observável continuem rodando (cada um é envolvido em
seu próprio `try`/`catch`), e a mesma isolação se aplica a implementações
de `ObserverInspector`. Um ciclo síncrono de atualização (o listener de A
escreve em B, o listener de B escreve em A, ...) é interrompido após uma
profundidade de notificação limitada, com um `ObserverCycleError`
descritivo, em vez de um stack overflow cru.

## Posso usar fora do Flutter (uma ferramenta CLI, um servidor)?

Sim, via `package:all_observer/core.dart` — `CoreObservable`,
`CoreComputed`, e o restante do motor têm zero import de
`package:flutter`. Veja
[Avançado](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md#packageall_observercoredart--o-motor-em-dart-puro).

## Funciona entre isolates?

Não — como o restante do Dart, todo `Observable`/`Computed`/coleção é
confinado ao isolate que o criou. Use `SendPort`/`ReceivePort` ou
`compute` para mover dados entre isolates e escrever de volta no
observável no seu próprio isolate.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Migrando do GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/migration_from_getx.md)
