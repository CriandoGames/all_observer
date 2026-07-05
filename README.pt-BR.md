# all_observer

🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/README.md) | 🇧🇷 Português

[![pub package](https://img.shields.io/pub/v/all_observer.svg)](https://pub.dev/packages/all_observer)
[![license: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![pub points](https://img.shields.io/pub/points/all_observer?label=pub%20points)](https://pub.dev/packages/all_observer/score)
![225 testes](https://img.shields.io/badge/tests-225-brightgreen)

Estado reativo para Flutter sem dependências — `final count = 0.obs;` +
`Observer(...)` e pronto.

![all_observer hero](https://raw.githubusercontent.com/CriandoGames/all_observer/main/documentation/images/hero.png)

## Sumário

- [Features](#features)
- [Instalando](#instalando)
- [Contador passo a passo](#contador-passo-a-passo)
- [Os blocos de construção](#os-blocos-de-construção)
- [Comparação](#comparação)
- [Quando usar (e quando não usar)](#quando-usar-e-quando-não-usar)
- [Documentação](#documentação)
- [Outros pacotes nossos](#outros-pacotes-nossos)

## Features

- 🪶 **Zero dependências** — todo o núcleo reativo é construído só com `Dart`/`Flutter`, nada mais para manter sincronizado com sua versão do Flutter.
- ✂️ **Sem boilerplate, sem code generation** — `final count = 0.obs;` mais `Observer(() => ...)` já é um par reativo completo e funcionando.
- 🎯 **Rebuilds granulares** — as dependências são descobertas ao *ler* `.value` durante um build, então só o widget que de fato lê um valor reconstrói.
- 🛡️ **Seguro por padrão** — dependências em diamante livres de glitch, async com segurança contra corrida, proteção contra widgets desmontados, e warnings amigáveis em vez de crashes (com `strictMode` opcional para CI).
- 🧪 **Testável por design** — `Observable`/`Computed` são objetos Dart puros, sem wrapper/DI necessário para testá-los; veja [Testes](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md).
- 🔌 **Interop com `ValueListenable`** — `Observable<T>` *é* um `ValueListenable<T>`, então entra direto em `ValueListenableBuilder`, `AnimatedBuilder`, `Listenable.merge`.
- 🩺 **Logging colorido embutido** — ative `ObserverConfig.logging = true` e acompanhe cada evento de criação/atualização/rastreamento/descarte no terminal.

## Instalando

```
flutter pub add all_observer
```

```yaml
dependencies:
  all_observer: ^1.3.1
```

```dart
import 'package:all_observer/all_observer.dart';
```

## Contador passo a passo

### Passo 1 — Crie um observável

```dart
final count = 0.obs; // ObservableInt
```

`.obs` envolve qualquer valor em um `Observable` — `count` agora guarda `0` e pode ser observado por mudanças.

### Passo 2 — Envolva sua UI em um Observer

```dart
import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

final count = 0.obs;

class CounterPage extends StatelessWidget {
  const CounterPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contador')),
      body: Center(
        child: Observer(() => Text('${count.value}')),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => count.value++,
        child: const Icon(Icons.add),
      ),
    );
  }
}
```

Rode dentro de qualquer `MaterialApp(home: CounterPage())`.

### Passo 3 — Atualize o valor

```dart
onPressed: () => count.value++,
```

Só o `Observer(() => Text('${count.value}'))` acima reconstrói — nada mais em `CounterPage` re-renderiza, porque ele é o único widget que leu `count.value` durante seu build.

### Passo 4 — Veja acontecendo

```dart
ObserverConfig.logging = true;
```

```
[all_observer] ✚ Observable<int>(count) criado → 0
[all_observer] 👁 Observer(sem-nome) rastreando: [count]
[all_observer] ↻ Observable<int>(count): 0 → 1
```

<!-- TODO: adicionar GIF do resultado — grave o demo do contador acima com ObserverConfig.logging = true, mostrando os toques no FAB junto com as linhas coloridas do log no terminal atualizando em sincronia. -->

## Os blocos de construção

### `Observable`

Qualquer valor envolvido com `.obs` (ou `Observable<T>(inicial)` para tipos customizados). Ler `.value` dentro de um builder rastreado registra uma dependência; escrever só notifica quando o novo valor difere.

```dart
final name = Observable<User?>(null, name: 'user');
name.value = User('Carlos');
```

[Mais sobre `Observable` aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md).

### `Observer`

Widget de auto-tracking: as dependências são redescobertas a cada build, então leituras condicionais funcionam sem esforço extra.

```dart
Observer(() => Text('${count.value}'));
```

[Mais sobre `Observer` aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md).

### `Computed`

Valor derivado preguiçoso e memoizado, construído sobre o mesmo rastreador que o `Observer` usa.

```dart
final fullName = Computed(() => '${firstName.value} ${lastName.value}');
Observer(() => Text(fullName.value)); // recalcula só quando necessário
```

[Mais sobre `Computed` aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md).

### Coleções reativas

`ObservableList`/`ObservableMap`/`ObservableSet` se comportam como suas equivalentes nativas, notificando no máximo uma vez por chamada mutante.

```dart
final items = <String>[].obs;
Observer(() => Text('${items.length} itens'));
items.addAll(['um', 'dois']); // notifica uma vez, não duas
```

[Mais sobre coleções aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md).

### `ObservableFuture` (estado assíncrono)

Executa uma `Future` e rastreia seu ciclo de carregando/dados/erro, com refreshes seguros contra corrida.

```dart
final userFuture = ObservableFuture<User>(() => api.fetchUser(id));
Observer(() => userFuture.value.when(
  loading: (previousData) => const CircularProgressIndicator(),
  data: (user) => Text(user.name),
  error: (error, stackTrace) => Text('Erro: $error'),
));
```

[Mais sobre estado assíncrono aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/async.md).

### Workers

`ever`, `once`, `debounce`, `interval` — efeitos colaterais disparados por mudança de observável, sem chamadas manuais a `addListener`.

```dart
final query = ''.obs;
final search = debounce(query, (String value) => runSearch(value),
    time: const Duration(milliseconds: 400));
```

[Mais sobre workers aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/workers.md).

### `batch`

Agrupa múltiplas escritas para que assinantes manuais (`listen`/`ever`) notifiquem uma vez em vez de uma por escrita — o `Observer` já agrupa rebuilds por frame por conta própria.

[Mais sobre `batch` e dependências em diamante aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md).

## Comparação

| | all_observer | GetX | Riverpod | Bloc | MobX | signals |
|---|---|---|---|---|---|---|
| Dependências externas | Zero | Zero (tudo em um) | `riverpod` (+ gerador, comum) | `bloc`, `flutter_bloc` | `mobx`, `build_runner` | Zero |
| Code generation | Nenhum | Nenhum | Opcional, comum na prática | Nenhum | Obrigatório (`@observable`/`@action`) | Nenhum |
| Boilerplate | Mínimo (`.obs` + `Observer`) | Mínimo | Declarações de provider | Eventos/estados/handlers | Classes de store anotadas | Mínimo |
| Granularidade de rebuild | Por leitura, auto-rastreado | Por leitura, auto-rastreado | Por `ref.watch` | Por `BlocBuilder`/seletor | Por leitura, auto-rastreado | Por leitura, auto-rastreado |
| Curva de aprendizado | Baixa | Baixa–média | Média | Média–alta | Média | Baixa |
| Escopo | Só reatividade | Framework completo (estado+rotas+DI) | Estado + grafo de DI | Arquitetura de máquina de estados/eventos | Reatividade + actions | Só reatividade |

`all_observer` propositalmente não faz roteamento, DI ou snackbars — isso é
uma escolha de design, não uma lacuna. [Comparação completa e detalhada aqui](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/comparison.md).

## Quando usar (e quando não usar)

Use `all_observer` quando quiser estado reativo — contadores, campos de
formulário, flags de carregamento, uma lista reativa, um resumo calculado —
sem adotar uma arquitetura completa, e quiser que componha com o DI/roteamento
que você já usa.

Escolha outra coisa quando precisar especificamente do que ela faz de melhor:
um grafo de DI verificado em tempo de compilação (Riverpod), um framework
completo com rotas e DI (GetX), ou uma arquitetura de evento/estado auditável
para um time grande (Bloc). `all_observer` não tem opinião sobre onde o
estado *vive*, só sobre como ele *notifica*, então compõe com qualquer um
deles.

## Documentação

- [Conceitos essenciais](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md) — `Observable`, `Observer`, rastreamento, `Computed`.
- [Coleções](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md) — `ObservableList`/`Map`/`Set`.
- [Assíncrono](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/async.md) — `ObservableFuture`, `ObservableStream`, `AsyncState`.
- [Workers](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/workers.md) — `ever`, `once`, `debounce`, `interval`.
- [Avançado](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md) — `batch`, dependências em diamante, `equals`, `setValue`, `strictMode`, logging, decisões de design, limitações.
- [Testes](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/testing.md) — como testar widgets e controllers que usam all_observer, com exemplos reais do app de exemplo.
- [Comparação](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/comparison.md) — comparação detalhada com GetX, Riverpod, Bloc, MobX, signals.
- [Migrando do GetX](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/migration_from_getx.md).
- [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/faq.md) — troubleshooting e perguntas frequentes.

## Outros pacotes nossos

`all_observer` faz parte de uma pequena família de pacotes Dart & Flutter
com zero/poucas dependências, publicados sob o publisher verificado
[`opensource.tatamemaster.com.br`](https://pub.dev/publishers/opensource.tatamemaster.com.br/packages):

| Pacote | Versão | Descrição |
|---|---|---|
| [`all_validations_br`](https://pub.dev/packages/all_validations_br) | [![pub](https://img.shields.io/pub/v/all_validations_br.svg)](https://pub.dev/packages/all_validations_br) | Validação de documentos brasileiros (CPF, CNPJ, CNH, PIX), formatadores/máscaras de input, utilitários de JWT/UUID/moeda/criptografia. |
| [`all_box`](https://pub.dev/packages/all_box) | [![pub](https://img.shields.io/pub/v/all_box.svg)](https://pub.dev/packages/all_box) | Armazenamento chave-valor síncrono com escritas seguras contra crash e uma camada reativa pura em Flutter. |
| [`all_image_compress`](https://pub.dev/packages/all_image_compress) | [![pub](https://img.shields.io/pub/v/all_image_compress.svg)](https://pub.dev/packages/all_image_compress) | Compressão de imagem em Dart puro (JPEG, PNG, GIF, BMP, TIFF, WebP), rodando em isolates. |

## 👥 Contribuidores

[![Contributors](https://contrib.rocks/image?repo=CriandoGames/all_observer)](https://github.com/CriandoGames/all_observer/graphs/contributors)

Feito com [contrib.rocks](https://contrib.rocks).

## Como contribuir

Contribuições são bem-vindas! Leia [CONTRIBUTING.md](CONTRIBUTING.md) para começar.

---

Issues e pull requests são bem-vindos no
[repositório do GitHub](https://github.com/CriandoGames/all_observer). Licenciado sob [MIT](LICENSE).
