🇧🇷 [Português](https://github.com/CriandoGames/all_observer/blob/main/documentation/pt-BR/tutorials.md) | 🇺🇸 English

# Tutorials: four small screens

Four deliberately small, self-contained examples — no architecture, no
folder structure, just the reactive parts. Each one builds on the same two
primitives from the [Core concepts](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/core_concepts.md)
guide: an `Observable` (via `.obs`) and an `Observer` widget that reads it.

- [1. Toggle button state](#1-toggle-button-state)
- [2. Loading screen](#2-loading-screen)
- [3. Login screen](#3-login-screen)
- [4. Infinite list](#4-infinite-list)

## 1. Toggle button state

The smallest possible example: a button that flips between two visual
states (and disables itself while "busy"), with no `setState` anywhere.

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
        label: Text(liked.value ? 'Liked' : 'Like'),
        style: ElevatedButton.styleFrom(
          backgroundColor: liked.value ? Colors.pink : null,
        ),
      ),
    );
  }
}
```

`liked` is created inside `build()` here only to keep the snippet
self-contained — in a real widget it belongs in a `State`, a controller, or
a global, not re-created on every rebuild. The `Observer` reads
`liked.value` twice (icon and label); both reads register against the same
`Observer`, so a toggle still triggers exactly one rebuild.

A busier variant — disable the button and show a spinner while an action
runs:

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
            : const Text('Submit'),
      ),
    );
  }

  Future<void> _submit() async {
    _submitting.value = true;
    await Future<void>.delayed(const Duration(seconds: 1)); // pretend request
    _submitting.value = false;
  }
}

final _submitting = false.obs;
```

`onPressed: null` is what actually disables a Flutter button — reading
`_submitting.value` to pick between `_submit` and `null` is the whole
trick.

## 2. Loading screen

A screen with three states — loading, data, error — driven by
`ObservableFuture`, covered in full in [Async state](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/async.md).

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
      appBar: AppBar(title: const Text('Profile')),
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
                  Text('Failed to load profile: $error'),
                  TextButton(
                    onPressed: () => _user.refresh(),
                    child: const Text('Retry'),
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

`ObservableFuture` runs `fetchUser()` on construction (`autoStart: true` by
default), so the screen starts in `loading` with no manual state juggling.
Pull-to-refresh and the retry button both just call `_user.refresh()` — the
built-in generation counter makes rapid double-taps safe, discarding the
stale response instead of racing it against the fresh one.

## 3. Login screen

Form validation and a submit flow that reads like plain synchronous code,
built from three observables and one `Computed`.

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
      _error.value = 'Invalid credentials';
    } finally {
      _submitting.value = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Log in')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(labelText: 'Email'),
              onChanged: (v) => _email.value = v,
            ),
            TextField(
              decoration: const InputDecoration(labelText: 'Password'),
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
                    : const Text('Log in'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`_canSubmit` is a `Computed` — it re-evaluates only when `_email` or
`_password` actually notify, and the submit button's `Observer` only
rebuilds when `_canSubmit.value` or `_submitting.value` changes, not on
every keystroke of an already-valid form. Note the two `TextField`s are
*not* wrapped in `Observer` — they only write, never read, so they don't
need to.

## 4. Infinite list

Pagination state (items, `isLoadingMore`, `hasMore`) as three observables
in a controller, driving a `ListView.builder` with a `ScrollController`
trigger. See also [Collections](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/collections.md)
for the full `ObservableList` API.

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
    items.addAll(next); // notifies once, not once per item
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
            // trailing loader/end-of-list row
            return _controller.hasMore.value
                ? const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  )
                : const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: Text('No more posts')),
                  );
          },
        ),
      ),
    );
  }
}
```

One `Observer` wraps the whole `ListView.builder`. It reads
`_controller.items.length` and, for the trailing row, `hasMore.value` — so
it rebuilds when a page is appended or when `hasMore` flips, and does
*not* rebuild on every `isLoadingMore` toggle (that flag only gates
`loadMore()`'s own re-entrancy check here; wire it into the trailing row
too if you also want a spinner *while* the next page is in flight, instead
of only reasoning about `hasMore`).

---

Back to [README](https://github.com/CriandoGames/all_observer/blob/main/README.md) · Previous: [FAQ](https://github.com/CriandoGames/all_observer/blob/main/documentation/en/faq.md)
