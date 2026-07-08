🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md) | 🇧🇷 Português

# Coleções reativas

`ObservableList<E>`, `ObservableMap<K, V>`, `ObservableSet<E>` — substitutas
reativas prontas para `List`/`Map`/`Set`.

## Contrato de leitura

Cada uma se comporta exatamente como sua equivalente nativa para toda
leitura — `length`, `[]`, `contains`, iteração — porque estendem
`ListBase`/`MapBase`/`SetBase` respectivamente. Qualquer leitura dentro de
um builder rastreado registra a coleção como dependência, assim como ler
`.value` em um `Observable` comum.

```dart
final items = <String>[].obs; // ObservableList<String>

Observer(() => Text('${items.length} itens'));
```

## Contrato de notificação

Todo membro mutante notifica **no máximo uma vez por chamada**, nunca uma
vez por elemento:

```dart
items.add('um');                      // notifica uma vez
items.addAll(['dois', 'três']);       // ainda uma vez, não três
items.removeWhere((e) => e == 'dois'); // uma vez, e só se algo casou
```

Uma mutação sem efeito notifica **zero** vezes:

- Adicionar a um `Set` um elemento que já existe.
- `removeWhere`/`retainWhere` que não casa com nada.
- Atribuir um valor idêntico a uma chave já existente de um `Map`.

Isso importa para a performance de `Observer`/`Computed`: uma operação em
massa em uma coleção grande gera um único rebuild, não um por elemento, e
uma mutação que não muda nada não gera rebuild algum.

## Exemplos

```dart
final tags = <String>{}.obs;      // ObservableSet<String>
Observer(() => Text('${tags.length} tags'));
tags.add('flutter');
tags.add('flutter'); // sem efeito, sem notificação — já presente

final scores = <String, int>{}.obs; // ObservableMap<String, int>
Observer(() => Text('${scores['carlos'] ?? 0}'));
scores['carlos'] = 10;
scores['carlos'] = 10; // sem efeito, mesmo valor já presente
```

## A única pegadinha: mutar um elemento no próprio lugar

Coleções reativas rastreiam *pertencimento e estrutura* (o que está na
coleção, e quantos itens), não o estado interno dos objetos dentro dela.
Mutar um objeto já guardado na coleção não notifica por conta própria:

```dart
final tasks = <Task>[].obs;
tasks.add(Task(done: false));

tasks.first.done = true; // muta o objeto Task diretamente — sem notificação
tasks.refresh();          // force isso, igual em um Observable comum
```

Chame `refresh()` (herdado de `Observable`) depois de mutar um objeto no
próprio lugar, exatamente como faria em um `Observable<T>` comum guardando
um objeto mutável.

## Construtores de fábrica em `ObservableList`

Além do construtor padrão (`ObservableList([initial])`), `ObservableList<E>`
tem construtores `factory` espelhando os equivalentes estáticos de `List`:

```dart
ObservableList<int>.filled(3, 0);        // [0, 0, 0]
ObservableList<int>.empty(growable: true);
ObservableList<int>.from(<dynamic>[1, 2]);
ObservableList<int>.of(<int>[1, 2]);
ObservableList<int>.generate(4, (i) => i * i); // [0, 1, 4, 9]
ObservableList<int>.unmodifiable(<int>[1, 2]); // lê normal, muta lança UnsupportedError
```

Todos aceitam um `name` opcional, usado no rótulo de debug (o mesmo que o
segundo parâmetro posicional do construtor padrão).

## Mutadores de conveniência em `ObservableList`

```dart
final items = <int>[1, 2, 3].obs;

items.assign(9);           // substitui tudo por [9], notifica uma vez
items.assignAll([4, 5]);   // substitui tudo por [4, 5], notifica uma vez

items.addIf(isLoggedIn, item);        // adiciona só se a condição for true
items.addAllIf(hasPermission, extras); // idem, para vários itens

items.addIfNotNull(parseOrNull(input)); // adiciona só se não for null
```

`assign`/`assignAll` existem para o caso comum de "substituir a lista
inteira" (ex.: resposta de uma busca) sem pagar o custo de duas
notificações (uma para o `clear()` implícito, outra para o `add`/`addAll`)
— assim como qualquer outro membro mutante da coleção, notificam no
máximo uma vez por chamada.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Conceitos essenciais](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md) · Próximo: [Assíncrono](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/async.md)
