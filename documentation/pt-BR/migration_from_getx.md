🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/migration_from_getx.md) | 🇧🇷 Português

# Migrando do GetX

`all_observer` cobre os mesmos conceitos de estado reativo que o GetX,
sob nomes majoritariamente equivalentes — este é um mapa conceito-a-
-conceito, não uma promessa de que toda API do GetX tem uma substituta
direta.

## Mapa de conceitos

| GetX | `all_observer` | Notas |
|---|---|---|
| `.obs` | `.obs` | Mesma sintaxe: `final count = 0.obs;` |
| `Rx<T>` / `RxInt`/`RxString`/... | `Observable<T>` / `ObservableInt`/`ObservableString`/... | Mesmo padrão de especialização |
| `Obx(() => ...)` | `Observer(() => ...)` | Ambos rastreiam automaticamente leituras de `.value` |
| `GetX<Controller>`/`GetBuilder` | `Observer` (o estado vive em uma classe comum que você possui) | Sem etapa de registro de controller necessária |
| `ever`, `once`, `debounce`, `interval` | Mesmos nomes: `ever`, `once`, `debounce`, `interval` | Assinaturas variam ligeiramente — ver [workers.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/workers.md) |
| Leitura/escrita de `.value` | Leitura/escrita de `.value` | Equivalente direto |
| Lista/mapa reativo (`RxList`, `RxMap`) | `ObservableList`, `ObservableMap`, `ObservableSet` | Ver [collections.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md) |
| `Get.put`/`Get.find` (DI) | *Sem equivalente* | Traga seu próprio DI — ver abaixo |
| `Get.to`/`Get.off` (rotas) | *Sem equivalente* | Use `Navigator`/`Router` do próprio Flutter |
| `Get.snackbar`/dialogs | *Sem equivalente* | Use `ScaffoldMessenger`/`showDialog` diretamente |

## Migração incremental

As duas bibliotecas podem coexistir durante uma transição — `all_observer`
não registra nada globalmente, então introduzi-lo junto a código GetX
existente é seguro. Um caminho comum:

1. Novas features usam `Observable`/`Observer` diretamente.
2. Classes `GetxController` existentes mantêm seu estado GetX por
   enquanto; converta campos para `Observable`s um controller de cada vez
   conforme forem tocados.
3. Mantenha o DI do GetX (`Get.put`/`Get.find`) e o roteamento até decidir
   o que os substitui — `all_observer` não tem opinião sobre nenhum dos
   dois, então isso não bloqueia nada.

```dart
// Antes (GetX)
class CounterController extends GetxController {
  final count = 0.obs;
  void increment() => count.value++;
}

// Depois (all_observer) — mesma forma, sem classe base de controller exigida
class CounterController {
  final count = 0.obs;
  void increment() => count.value++;
  void dispose() => count.close();
}
```

## O que não migra

`all_observer` só lida com *reatividade*, por design — isso precisa de
outra ferramenta, não de uma portabilidade:

- **Injeção de dependência / service location.** Traga seu próprio DI (um
  singleton simples passado por construtor, um `InheritedWidget`, ou um
  pacote de DI dedicado) e guarde `Observable`s dentro dos
  serviços/controllers que ele gerencia.
- **Roteamento / navegação.** Use o `Navigator`/`Router` do próprio
  Flutter, ou um pacote de roteamento dedicado.
- **Snackbars / dialogs / overlays.** Use `ScaffoldMessenger`,
  `showDialog`, `showModalBottomSheet` etc. do próprio Flutter diretamente
  — `all_observer` não tem camada de efeito-colateral-de-UI para se
  conectar a esses.

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Comparação](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/comparison.md) · Próximo: [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/faq.md)
