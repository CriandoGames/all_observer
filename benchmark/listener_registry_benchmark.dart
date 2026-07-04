// ignore_for_file: avoid_print
import 'package:all_observer/src/core/listener_registry.dart';

/// Manual `Stopwatch`-based microbenchmark comparing the cost of adding,
/// removing and notifying 1000 listeners on a [ListenerRegistry], before
/// and after the v1.1.0 switch from a `List<VoidCallback>` (O(n)
/// `contains`/`remove`) to a `LinkedHashSet<VoidCallback>` (O(1) `add`/
/// `remove`/`contains`, insertion order preserved).
///
/// This is not a `benchmark_harness`-based benchmark (the package has zero
/// external dependencies, including dev-only ones used at runtime by the
/// library itself) — it's a plain, runnable Dart script using `Stopwatch`,
/// consistent with the rest of `/benchmark`.
///
/// Run with: `dart run benchmark/listener_registry_benchmark.dart`
///
/// Microbenchmark manual baseado em `Stopwatch` comparando o custo de
/// adicionar, remover e notificar 1000 listeners em um [ListenerRegistry],
/// antes e depois da troca (v1.1.0) de uma `List<VoidCallback>`
/// (`contains`/`remove` O(n)) para um `LinkedHashSet<VoidCallback>` (`add`/
/// `remove`/`contains` O(1), ordem de inserção preservada).
///
/// Este não é um benchmark baseado em `benchmark_harness` (o pacote tem
/// zero dependências externas, incluindo as usadas apenas em
/// desenvolvimento em tempo de execução pela própria biblioteca) — é um
/// script Dart simples e executável usando `Stopwatch`, consistente com o
/// restante de `/benchmark`.
///
/// Execute com: `dart run benchmark/listener_registry_benchmark.dart`
void main() {
  const int listenerCount = 1000;
  const int lookupIterations = 5000;

  print('ListenerRegistry benchmark ($listenerCount listeners)');
  print('-------------------------------------------------------');

  final ListenerRegistry registry = ListenerRegistry();
  final List<void Function()> listeners = List<void Function()>.generate(
    listenerCount,
    (int i) => () {},
  );

  final Stopwatch addWatch = Stopwatch()..start();
  for (final void Function() listener in listeners) {
    registry.add(listener);
  }
  addWatch.stop();
  print('add() x$listenerCount: ${addWatch.elapsedMicroseconds}us');

  // `contains` on the last-added listener is the worst case for a
  // List-backed implementation (full linear scan); with the current
  // LinkedHashSet-backed implementation this is O(1) regardless of
  // position.
  final Stopwatch containsWatch = Stopwatch()..start();
  for (int i = 0; i < lookupIterations; i++) {
    registry.contains(listeners.last);
  }
  containsWatch.stop();
  print(
    'contains(last) x$lookupIterations: '
    '${containsWatch.elapsedMicroseconds}us',
  );

  final Stopwatch notifyWatch = Stopwatch()..start();
  registry.notifyAll();
  notifyWatch.stop();
  print('notifyAll() (1 pass): ${notifyWatch.elapsedMicroseconds}us');

  final Stopwatch removeWatch = Stopwatch()..start();
  for (final void Function() listener in listeners) {
    registry.remove(listener);
  }
  removeWatch.stop();
  print('remove() x$listenerCount: ${removeWatch.elapsedMicroseconds}us');

  print('-------------------------------------------------------');
  print(
    'Done. Compare against a git stash of the pre-1.1.0 List-backed '
    'ListenerRegistry to see the O(n) -> O(1) improvement on contains()/'
    'remove(), most visible as listenerCount grows.',
  );
}
