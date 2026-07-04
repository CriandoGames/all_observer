# all_observer

🇬🇧 [Read in English](README.md)

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![CI](https://img.shields.io/github/actions/workflow/status/CriandoGames/all_observer/ci.yml?branch=main)](https://github.com/CriandoGames/all_observer/actions)

Estado reativo para Flutter, sem dependências. Valores `Observable` mais um
widget `Observer` com auto-rastreamento — um núcleo pequeno, seguro e sem
dependências para apps que querem reatividade sem um framework completo de
gerenciamento de estado.

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

Um `Observable.select` no estilo `user.select((u) => u.name)` foi
propositalmente deixado de fora como API separada: escreva diretamente
`Computed(() => user.value.name)`.

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
- `Computed<T>`: valores derivados preguiçosos e memoizados, construídos sobre o mesmo rastreador de dependências do `Observer`.
- `Observable.batch`: agrupa múltiplas escritas em uma única notificação por observável alterado, para assinantes manuais.
- `ObserverValue<T>`: estado reativo local e autocontido, sem gerenciar o ciclo de vida de um observável separadamente.
- `ever`, `once`, `debounce`, `interval`: workers para efeitos colaterais disparados por mudanças em observáveis.
- Um ciclo de atualização síncrono (o listener de A escreve em B, o de B escreve em A, ...) é interrompido após uma profundidade de notificação limitada, com um erro descritivo, em vez de um stack overflow bruto; uma exceção lançada dentro de um listener nunca impede que os demais listeners do mesmo observável rodem.
- Veja `/example` para uma demonstração executável (contador, lista reativa, worker, alternador de logs de debug), e `/benchmark` para microbenchmarks manuais baseados em Stopwatch.

## Contribuindo

Issues e pull requests são bem-vindos no
[repositório do GitHub](https://github.com/CriandoGames/all_observer).
