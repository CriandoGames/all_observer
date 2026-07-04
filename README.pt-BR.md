# all_observer

🇬🇧 [Read in English](README.md)

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
<a href="https://pub.dev/packages/all_observer/score"><img src="https://img.shields.io/pub/points/all_observer?label=pub%20points" alt="pub points"></a>
 <img src="https://img.shields.io/badge/testes-18-brightgreen" alt="156 testes">


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
- `ObservableFuture<T>` / `AsyncState<T>`: estado assíncrono de carregando/dados/erro, seguro contra corrida, construído sobre `Observable`.
- `Observable.batch`: agrupa múltiplas escritas em uma única notificação por observável alterado, para assinantes manuais.
- `Observer.withChild`: reconstrói apenas a parte de uma subárvore que pertence ao builder, reaproveitando um `child` estático entre rebuilds.
- `Observable.select`: açúcar sintático para um `Computed` mais estreito derivado de um único `Observable`.
- `ObserverValue<T>`: estado reativo local e autocontido, sem gerenciar o ciclo de vida de um observável separadamente.
- `ever`, `once`, `debounce`, `interval`: workers para efeitos colaterais disparados por mudanças em observáveis.
- Um ciclo de atualização síncrono (o listener de A escreve em B, o de B escreve em A, ...) é interrompido após uma profundidade de notificação limitada, com um erro descritivo, em vez de um stack overflow bruto; uma exceção lançada dentro de um listener nunca impede que os demais listeners do mesmo observável rodem.
- Veja `/example` para uma demonstração executável (contador, lista reativa, worker, alternador de logs de debug), e `/benchmark` para microbenchmarks manuais baseados em Stopwatch.

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

- **Glitch do diamante fora do `batch`.** Um grafo de dependências em
  diamante (dois `Computed` derivados da mesma origem, um terceiro
  dependendo de ambos) pode recalcular mais de uma vez, e brevemente
  observar uma mistura de um ramo já atualizado com outro ainda
  desatualizado, quando as escritas a montante acontecem fora de
  `Observable.batch()`. Envolva essas escritas em `batch()` para obter
  exatamente um recompute por `Computed` afetado, sempre a partir de
  valores a montante consistentes.
- **Cascatas mais profundas, cruzando ramos, dentro de um `batch` podem
  recalcular uma vez a mais do que o estritamente necessário — nunca de
  forma inconsistente, e nunca com uma notificação extra.** O flush que
  mitiga o glitch do diamante (acima) processa mudanças em ondas; um
  `Computed` alcançável por dois caminhos diferentes na mesma onda (ex.:
  uma dependência a duas camadas de distância da escrita, e uma segunda
  dependência a apenas uma camada) pode acabar recalculando esse mesmo
  valor, já correto, uma segunda vez antes do flush se estabilizar. Todo
  recompute ainda enxerga apenas valores a montante totalmente
  consistentes (nunca um intermediário obsoleto/misto), e como o recompute
  redundante sempre produz o valor idêntico, ele nunca dispara uma segunda
  notificação para os listeners daquele `Computed` — apenas a contagem
  interna de recomputes é afetada, e só para grafos com esse formato. Um
  diamante simples de dois `Computed`s (veja acima) não é afetado e sempre
  recalcula exatamente uma vez.
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
