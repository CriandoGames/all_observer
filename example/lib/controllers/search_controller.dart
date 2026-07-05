import 'package:all_observer/all_observer.dart';

/// Default fruit catalog used by [FruitSearchController] when no [catalog]
/// is injected.
///
/// Catálogo padrão de frutas usado por [FruitSearchController] quando
/// nenhum [catalog] é injetado.
const List<String> defaultFruitCatalog = <String>[
  'apple',
  'banana',
  'cherry',
  'date',
  'elderberry',
  'fig',
  'grape',
  'honeydew',
  'kiwi',
  'lemon',
  'mango',
  'nectarine',
  'orange',
  'papaya',
];

/// Business logic for [SearchDemo]: a debounced query filtering a catalog.
/// Extracted from `State` so both [catalog] and the debounce [time] can be
/// injected via the constructor — the catalog for deterministic assertions,
/// the time so tests can use a short debounce window instead of the demo's
/// real-world 400ms.
///
/// Lógica de negócio de [SearchDemo]: uma query com debounce filtrando um
/// catálogo. Extraída do `State` para que tanto [catalog] quanto o [time]
/// de debounce possam ser injetados via construtor — o catálogo para
/// asserções determinísticas, o tempo para que os testes usem uma janela de
/// debounce curta em vez dos 400ms reais do demo.
class FruitSearchController {
  /// Creates a controller filtering [catalog] (defaults to
  /// [defaultFruitCatalog]), debounced by [time] (defaults to 400ms, the
  /// same value the demo UI uses).
  ///
  /// Cria um controller filtrando [catalog] (padrão: [defaultFruitCatalog]),
  /// com debounce de [time] (padrão: 400ms, o mesmo valor usado na UI do
  /// demo).
  FruitSearchController({
    List<String> catalog = defaultFruitCatalog,
    Duration time = const Duration(milliseconds: 400),
  }) : _catalog = catalog {
    _runSearch(query.value);
    _debounceWorker = debounce(query, _runSearch, time: time);
  }

  final List<String> _catalog;
  late final Worker _debounceWorker;

  /// The current (immediate, not debounced) search text.
  ///
  /// O texto de busca atual (imediato, sem debounce).
  final ObservableString query = ''.obs;

  /// Filtered matches from the last real search run.
  ///
  /// Correspondências filtradas da última execução real de busca.
  final ObservableList<String> results = <String>[].obs;

  /// How many times a real (debounced) search actually ran.
  ///
  /// Quantas vezes uma busca real (debounced) de fato rodou.
  final ObservableInt searchRuns = 0.obs;

  void _runSearch(String value) {
    searchRuns.value++;
    final String needle = value.trim().toLowerCase();
    final List<String> matches = needle.isEmpty
        ? _catalog
        : _catalog.where((String item) => item.contains(needle)).toList();
    results
      ..clear()
      ..addAll(matches);
  }

  /// Releases every observable and worker this controller owns. Call from
  /// `State.dispose()`.
  ///
  /// Libera todo observável e worker que este controller possui. Chame a
  /// partir de `State.dispose()`.
  void dispose() {
    _debounceWorker.dispose();
    query.close();
    results.close();
    searchRuns.close();
  }
}
