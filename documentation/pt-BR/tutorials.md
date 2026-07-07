🇺🇸 [English](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/tutorials.md) | 🇧🇷 Português

# Tutoriais: quatro telinhas

Quatro exemplos propositalmente pequenos e autocontidos — sem arquitetura,
sem estrutura de pastas, só a parte reativa. Cada um usa os mesmos dois
blocos do guia [Conceitos essenciais](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/core_concepts.md):
um `Observable` (via `.obs`) e um widget `Observer` que o lê.

- [1. Mudar o estado de um botão](#1-mudar-o-estado-de-um-botão)
- [2. Tela de loading](#2-tela-de-loading)
- [3. Tela de login](#3-tela-de-login)
- [4. Lista infinita](#4-lista-infinita)

## 1. Mudar o estado de um botão

O exemplo mais simples possível: um botão que alterna entre dois estados
visuais (e se desabilita enquanto está "ocupado"), sem nenhum `setState`.

```dart
import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

class LikeButton extends StatelessWidget {
  const LikeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final liked = false.obs;

    return Observer(
      () => ElevatedButton.icon(
        onPressed: () => liked.value = !liked.value,
        icon: Icon(liked.value ? Icons.favorite : Icons.favorite_border),
        label: Text(liked.value ? 'Curtido' : 'Curtir'),
        style: ElevatedButton.styleFrom(
          backgroundColor: liked.value ? Colors.pink : null,
        ),
      ),
    );
  }
}
```

`liked` é criado dentro do `build()` aqui só para manter o snippet
autocontido — em um widget de verdade ele pertence a uma `State`, um
controller, ou um global, não deve ser recriado a cada rebuild. O
`Observer` lê `liked.value` duas vezes (ícone e texto); ambas as leituras
se registram no mesmo `Observer`, então alternar o estado dispara
exatamente um rebuild.

Uma variante um pouco mais completa — desabilitar o botão e mostrar um
spinner enquanto uma ação roda:

```dart
class SubmitButton extends StatelessWidget {
  const SubmitButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Observer(
      () => ElevatedButton(
        onPressed: _submitting.value ? null : _submit,
        child: _submitting.value
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Text('Enviar'),
      ),
    );
  }

  Future<void> _submit() async {
    _submitting.value = true;
    await Future<void>.delayed(const Duration(seconds: 1)); // finge uma requisição
    _submitting.value = false;
  }
}

final _submitting = false.obs;
```

`onPressed: null` é o que de fato desabilita um botão no Flutter — ler
`_submitting.value` para escolher entre `_submit` e `null` é todo o truque.

## 2. Tela de loading

Uma tela com três estados — loading, dados, erro — controlada por
`ObservableFuture`, detalhado em [Estado assíncrono](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/async.md).

```dart
import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late final ObservableFuture<User> _user;

  @override
  void initState() {
    super.initState();
    _user = ObservableFuture<User>(() => api.fetchUser());
  }

  @override
  void dispose() {
    _user.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
      body: RefreshIndicator(
        onRefresh: () => _user.refresh(),
        child: Observer(
          () => _user.value.when(
            loading: (previousData) =>
                const Center(child: CircularProgressIndicator()),
            data: (user) => ListView(
              children: [
                ListTile(title: Text(user.name), subtitle: Text(user.email)),
              ],
            ),
            error: (error, stackTrace) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Falha ao carregar o perfil: $error'),
                  TextButton(
                    onPressed: () => _user.refresh(),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

`ObservableFuture` roda `fetchUser()` já na construção (`autoStart: true`
por padrão), então a tela já começa em `loading` sem nenhum controle manual
de estado. O pull-to-refresh e o botão de tentar novamente só chamam
`_user.refresh()` — o contador de geração interno torna toques duplos
seguros, descartando a resposta antiga em vez de deixá-la competir com a
mais nova.

## 3. Tela de login

Validação de formulário e fluxo de envio que se lê como código síncrono
comum, construído com três observables e um `Computed`.

```dart
import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _email = ''.obs;
  final _password = ''.obs;
  final _submitting = false.obs;
  final _error = Observable<String?>(null);
  late final Computed<bool> _canSubmit;

  @override
  void initState() {
    super.initState();
    _canSubmit = Computed(
      () => _email.value.contains('@') && _password.value.length >= 6,
    );
  }

  @override
  void dispose() {
    _email.close();
    _password.close();
    _submitting.close();
    _error.close();
    _canSubmit.close();
    super.dispose();
  }

  Future<void> _submit() async {
    _submitting.value = true;
    _error.value = null;
    try {
      await api.login(_email.value, _password.value);
    } catch (e) {
      _error.value = 'Credenciais inválidas';
    } finally {
      _submitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Entrar')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: (v) => _email.value = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Senha'),
              obscureText: true,
              onChanged: (v) => _password.value = v,
            ),
            Observer(
              () => _error.value != null
                  ? Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        _error.value!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            const SizedBox(height: 16),
            Observer(
              () => ElevatedButton(
                onPressed: _canSubmit.value && !_submitting.value
                    ? _submit
                    : null,
                child: _submitting.value
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Entrar'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`_canSubmit` é um `Computed` — só reavalia quando `_email` ou `_password`
de fato notificam, e o `Observer` do botão só reconstrói quando
`_canSubmit.value` ou `_submitting.value` muda, não a cada tecla digitada
em um formulário já válido. Note que os dois `TextField` *não* estão
dentro de um `Observer` — eles só escrevem, nunca leem, então não
precisam.

## 4. Lista infinita

Estado de paginação (itens, `isLoadingMore`, `hasMore`) como três
observables em um controller, alimentando um `ListView.builder` com um
`ScrollController` como gatilho. Veja também [Coleções](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/collections.md)
para a API completa de `ObservableList`.

```dart
import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

class FeedController {
  final items = <Post>[].obs;
  final isLoadingMore = false.obs;
  final hasMore = true.obs;
  int _page = 0;

  Future<void> loadMore() async {
    if (isLoadingMore.value || !hasMore.value) return;
    isLoadingMore.value = true;
    final next = await api.fetchPosts(page: _page);
    items.addAll(next); // notifica uma vez, não uma vez por item
    hasMore.value = next.isNotEmpty;
    _page++;
    isLoadingMore.value = false;
  }

  void close() {
    items.close();
    isLoadingMore.close();
    hasMore.close();
  }
}

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final _controller = FeedController();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _controller.loadMore();
    _scroll.addListener(() {
      final nearBottom =
          _scroll.position.pixels > _scroll.position.maxScrollExtent - 200;
      if (nearBottom) _controller.loadMore();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feed')),
      body: Observer(
        () => ListView.builder(
          controller: _scroll,
          itemCount: _controller.items.length + 1,
          itemBuilder: (context, index) {
            if (index < _controller.items.length) {
              final post = _controller.items[index];
              return ListTile(title: Text(post.title));
            }
            // linha final: loader ou fim da lista
            return _controller.hasMore.value
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('Não há mais posts')),
                  );
          },
        ),
      ),
    );
  }
}
```

Um único `Observer` envolve o `ListView.builder` inteiro. Ele lê
`_controller.items.length` e, na linha final, `hasMore.value` — então
reconstrói quando uma página é adicionada ou quando `hasMore` muda, e
*não* reconstrói a cada alternância de `isLoadingMore` (aqui essa flag só
protege a reentrância do próprio `loadMore()`; ligue-a também na linha
final se você quiser um spinner *durante* o carregamento da próxima
página, e não só reagir a `hasMore`).

---

Voltar ao [README](https://github.com/CriandoGames/all_observer/blob/main/README.pt-BR.md) · Anterior: [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/faq.md)
