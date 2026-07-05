🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/workers.md) | 🇧🇷 Português

# Workers

`ever`, `once`, `debounce`, `interval` — a forma recomendada de rodar
efeitos colaterais fora de widgets (chamadas de rede, analytics,
persistência) a partir de uma mudança de observável, em vez de espalhar
chamadas manuais a `addListener`.

Cada um retorna um `Worker` com um método `dispose()`; agrupe vários com
`Workers([...]).dispose()`.

## `ever` — roda a cada mudança

```dart
final count = 0.obs;
final everWorker = ever(count, (int value) => print('count agora é $value'));
```

Um listener manual com um nome mais amigável — roda o callback com o novo
valor toda vez que `count` mudar. `dispose()` o cancela.

## `once` — roda uma única vez, e se autodescarta

```dart
final isLoggedIn = false.obs;
once(isLoggedIn, (bool value) {
  if (value) analytics.logLogin();
});
```

Dispara exatamente uma vez, na primeira mudança, e então para de escutar
automaticamente — sem precisar guardar uma referência para descartá-lo
você mesmo (embora o `Worker` retornado ainda possa ser descartado
antecipadamente se o evento nunca disparar).

## `debounce` — roda depois que as mudanças se estabilizam

```dart
final query = ''.obs;
final search = debounce(query, (String value) {
  runSearch(value);
}, time: const Duration(milliseconds: 400));
```

Roda 400ms depois da *última* mudança — perfeito para busca-enquanto-digita.
Toda mudança nova reinicia o timer; o callback só dispara quando o valor
parar de mudar pelo tempo completo. O `Timer` interno é cancelado no
`dispose()`.

## `interval` — roda no máximo uma vez por duração

```dart
final scrollOffset = 0.0.obs;
final saveScroll = interval(scrollOffset, (double value) {
  saveScrollPosition(value);
}, time: const Duration(seconds: 1));
```

Dispara imediatamente na primeira mudança, depois no máximo uma vez por
`time` enquanto o observável continuar mudando — o valor mais recente ao
final de cada janela de espera é o que é entregue (um flush de borda
final), não cada valor intermediário. Bom para limitar algo como
persistência de posição de scroll que de outra forma dispararia a cada
frame.

## Agrupamento e descarte

```dart
final debounceWorker = debounce(query, runSearch, time: const Duration(milliseconds: 400));
final everWorker = ever(count, (int value) => print(value));
final intervalWorker = interval(scrollOffset, saveScrollPosition, time: const Duration(seconds: 1));

Workers([debounceWorker, everWorker, intervalWorker]).dispose();
```

`once` se autodescarta após disparar; `debounce`/`interval` cancelam seu
`Timer` interno no `dispose()` para que nada dispare depois que você
terminar com eles — sempre descarte workers dos quais você guarda uma
referência (tipicamente em `State.dispose()`, idealmente via
`ObserverStateMixin.autoDispose` — ver
[advanced.md](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md)).

## Exemplos reais

```dart
// Analytics: dispara uma vez quando uma sessão de fato começa.
once(isLoggedIn, (bool v) { if (v) analytics.logSessionStart(); });

// Autosave: espera o usuário parar de digitar antes de gravar em disco.
final autosave = debounce(draftText, (String text) => storage.save(text),
    time: const Duration(seconds: 2));

// Busca-enquanto-digita: debounce na query, não em cada tecla.
final liveSearch = debounce(searchQuery, (String q) => repository.search(q),
    time: const Duration(milliseconds: 300));
```

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [Assíncrono](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/async.md) · Próximo: [Avançado](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/advanced.md)
