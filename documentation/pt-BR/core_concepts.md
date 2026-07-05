🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md) | 🇧🇷 Português

# Conceitos essenciais

`Observable`, `Observer`, rastreamento de dependências e `Computed` — o
núcleo reativo sobre o qual tudo mais no `all_observer` é construído.

## O modelo mental: rastreamento automático de dependências

Todo `Observable<T>` (e suas subclasses — `Computed`, `ObservableFuture`,
coleções) guarda um valor e um conjunto de listeners. Quando você lê
`.value` dentro do builder de um `Observer`, de um `effect()`, ou da função
de cálculo de um `Computed`, essa leitura é registrada em uma pilha de
`DependencyTracker` — o callback rastreado em execução no momento se
inscreve automaticamente no registro do observável. Não existe uma etapa
separada de declaração: ler *é* se inscrever.

As dependências são **redescobertas a cada execução**. Um `Observer` limpa
suas inscrições anteriores antes de reconstruir, depois rastreia o que o
builder ler desta vez. Isso significa que branches condicionais funcionam
corretamente sem esforço extra:

```dart
Observer(() => isLoggedIn.value ? Text(user.value.name) : const LoginButton());
```

Quando `isLoggedIn` é `false`, este `Observer` depende só de `isLoggedIn` —
`user` nunca é lido, então uma mudança em `user` enquanto deslogado não
causa rebuild. No momento em que `isLoggedIn` vira `true` e o widget
reconstrói, `user` também se torna uma dependência rastreada.

## `Observable<T>`

Crie um com `.obs` (`0.obs`, `'oi'.obs`, `false.obs`, `9.99.obs`,
`<String>[].obs`) ou o construtor diretamente para tipos customizados:

```dart
final user = Observable<User?>(null, name: 'user');
```

`name` é opcional e só é usado em logs/warnings de debug — quando omitido,
um rótulo curto baseado em hash é usado no lugar.

Leitura e escrita:

```dart
final count = 0.obs;
print(count.value); // leitura
count.value = 1;    // escrita — notifica só se 1 != 0
```

Uma escrita só notifica os listeners quando o novo valor difere do atual
via `==`. Não há caso especial para a primeira atribuição — a regra é
sempre "mudou ou não".

### `refresh()`

Para objetos mutáveis cujo estado interno mudou sem substituir a
referência (ex.: mutar um campo de um objeto guardado pelo observável), o
`==` não vai detectar diferença, já que a referência é idêntica. Chame
`refresh()` para forçar uma notificação:

```dart
final settings = Observable<Settings>(Settings());
settings.value.darkMode = true; // muta no próprio lugar, ainda sem notificação
settings.refresh(); // agora os listeners são notificados
```

### `equals` customizado

```dart
final price = Observable<double>(9.99, equals: (a, b) => (a - b).abs() < 0.01);
```

Sobrescreve a comparação `==` padrão — útil para tolerâncias de ponto
flutuante, ou para comparar apenas parte de um objeto maior.

### `listen()`

Inscreva-se sem um widget `Observer`:

```dart
final sub = count.listen((value) => print('agora $value'), immediate: false);
sub.cancel();
```

Passe `when: (value) => value > 0` para só invocar o callback enquanto o
predicado for verdadeiro — uma simples guarda `if`, sem rastreamento
extra envolvido.

### `close()`

Descarta o observável: remove todos os listeners e o marca como fechado.
Escritas subsequentes são ignoradas com um warning de debug em vez de
quebrar o app. Sempre chame `close()` em um `Observable`/`Computed`/coleção
que você criou manualmente quando terminar de usá-lo (ex.: em um
`State.dispose()`).

## `Observer`

```dart
Observer(() => Text('${count.value}'));
```

Reconstrói automaticamente sempre que qualquer observável lido dentro de
`builder` mudar. Os rebuilds são agrupados por frame — múltiplas mudanças
de dependência no mesmo frame disparam um único rebuild, não um por
mudança — e protegidos contra widgets já desmontados.

Um `Observer` que não lê nenhum observável nunca vai reconstruir; isso é
tratado como um provável engano e gera um warning de debug (ou lança uma
exceção, sob `strictMode` — ver [advanced.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md)).

### `Observer.withChild`

Para uma subárvore estática que não depende de nenhum observável:

```dart
Observer.withChild(
  builder: (context, child) => Row(children: [Text('${count.value}'), child]),
  child: const ExpensiveStaticWidget(),
);
```

`child` é construído uma vez e repassado para `builder` a cada rebuild em
vez de ser reconstruído — a mesma técnica que os parâmetros `child`
resolvem em outros pontos do Flutter.

## `Computed<T>`

Um valor derivado somente leitura, preguiçoso e memoizado:

```dart
final firstName = 'Carlos'.obs;
final lastName = 'Castro'.obs;
final fullName = Computed(() => '${firstName.value} ${lastName.value}');
Observer(() => Text(fullName.value)); // recalcula só quando necessário
```

`compute` nunca roda antes da primeira leitura de `.value`. Leituras
subsequentes retornam o resultado em cache até que uma dependência
notifique. Um recálculo só notifica seus próprios listeners se o novo
valor realmente diferir (`==`, ou um `equals` customizado) do anterior —
uma dependência que muda sem afetar o resultado derivado não causa
rebuild a jusante.

`Computed` reaproveita exatamente o mesmo `DependencyTracker` que o
`Observer` usa, então dependências condicionais/dinâmicas dentro de
`compute` funcionam da mesma forma. Chame `close()` quando terminar de
usar um `Computed` criado manualmente — ele fica inscrito em suas
dependências indefinidamente caso contrário (ver
[Limitações conhecidas](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md)).

### `select`

Açúcar sintático para um `Computed` mais estreito derivado de um único
`Observable`:

```dart
final user = Observable<User>(User(name: 'Carlos', age: 30));
final userName = user.select((u) => u.name); // == Computed(() => user.value.name)
```

Quem chama é dono do `Computed` retornado e deve chamar `close()` nele.

## Interop com `ValueListenable`

Todo `Observable<T>` (e `Computed<T>`) implementa `ValueListenable<T>`,
então entra direto em qualquer coisa que já fale essa interface:

```dart
ValueListenableBuilder<int>(
  valueListenable: count,
  builder: (context, value, _) => Text('$value'),
);

AnimatedBuilder(animation: Listenable.merge([count, otherObservable]), ...);
```

## Tutorial guiado: do contador a uma pequena lista de tarefas

Partindo do contador do README, aqui está um exemplo um pouco maior que usa
`Computed` para um resumo derivado, e fecha tudo no `dispose()`:

```dart
class _TaskListState extends State<TaskList> {
  final ObservableList<Task> _tasks = <Task>[].obs;
  late final Computed<String> _summary;

  @override
  void initState() {
    super.initState();
    _summary = Computed(() {
      final int done = _tasks.where((t) => t.done).length;
      return '$done de ${_tasks.length} concluídas';
    });
  }

  @override
  void dispose() {
    _tasks.close();
    _summary.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Observer(() => Text(_summary.value)),
        Expanded(
          child: Observer(
            () => ListView(
              children: _tasks
                  .map((t) => CheckboxListTile(
                        value: t.done,
                        title: Text(t.title),
                        onChanged: (v) => t.done = v ?? false,
                      ))
                  .toList(),
            ),
          ),
        ),
      ],
    );
  }
}
```

`_summary` só recalcula quando `_tasks` notifica (um add/remove/mutação), e
só reconstrói o `Observer` acima se a string resultante realmente mudar.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Próximo: [Coleções](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md)
