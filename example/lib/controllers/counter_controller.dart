import 'package:all_observer/all_observer.dart';

/// Business logic for [CounterDemo], extracted from `State` so it can be
/// unit tested without Flutter and injected via the constructor.
///
/// Lógica de negócio de [CounterDemo], extraída do `State` para poder ser
/// testada sem Flutter e injetada via construtor.
class CounterController {
  /// Creates a controller starting [count] at [initialCount].
  ///
  /// Cria um controller com [count] iniciando em [initialCount].
  CounterController({int initialCount = 0}) : count = initialCount.obs {
    // `compute` only derives the value — it must never write to another
    // observable while it runs. `Computed` shares the same tracking stack
    // `Observer` uses, so mutating `log` (an ObservableList) from inside
    // `compute` is exactly the "write during tracking" mistake the
    // library warns about (it would even show up as a console warning).
    doubled = Computed<int>(() {
      computeRuns++;
      return count.value * 2;
    });
    // Log every recompute from *outside* the tracked scope instead: once
    // here for the eager first read, then via `listen`, whose callback
    // always fires after `compute` has already returned.
    log.add('compute #$computeRuns -> ${doubled.value}');
    doubled.listen((int value) => log.add('compute #$computeRuns -> $value'));
  }

  /// The raw counter.
  ///
  /// O contador bruto.
  final ObservableInt count;

  /// Derived value: double the counter, recomputed only when [count]
  /// actually changes.
  ///
  /// Valor derivado: o dobro do contador, recalculado somente quando
  /// [count] realmente muda.
  late final Computed<int> doubled;

  /// One entry per real recompute of [doubled] — proves memoization.
  ///
  /// Uma entrada por recomputo real de [doubled] — prova a memoização.
  final ObservableList<String> log = <String>[].obs;

  /// How many times [doubled]'s `compute` body actually ran.
  ///
  /// Quantas vezes o corpo `compute` de [doubled] realmente rodou.
  int computeRuns = 0;

  /// Increments [count] by one.
  ///
  /// Incrementa [count] em um.
  void increment() => count.value++;

  /// Resets [count] to zero.
  ///
  /// Reseta [count] para zero.
  void reset() => count.setValue(0);

  /// Releases every observable this controller owns. Call from
  /// `State.dispose()`.
  ///
  /// Libera todo observável que este controller possui. Chame a partir de
  /// `State.dispose()`.
  void dispose() {
    count.close();
    doubled.close();
    log.close();
  }
}
