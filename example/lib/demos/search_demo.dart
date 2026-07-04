import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

/// Demo 2: a `TextField` feeding an `Observable<String>` query, debounced
/// 400ms via the `debounce` worker, filtering an `ObservableList` of
/// results.
///
/// Demo 2: um `TextField` alimentando uma query `Observable<String>`,
/// debounced em 400ms via o worker `debounce`, filtrando uma
/// `ObservableList` de resultados.
class SearchDemo extends StatefulWidget {
  /// Creates the debounced search demo.
  ///
  /// Cria o demo de busca com debounce.
  const SearchDemo({super.key});

  @override
  State<SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<SearchDemo> {
  static const List<String> _catalog = <String>[
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

  final ObservableString _query = ''.obs;
  final ObservableList<String> _results = <String>[].obs;
  final ObservableInt _searchRuns = 0.obs;
  late final Worker _debounceWorker;
  final TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _runSearch(_query.value);
    _debounceWorker = debounce(
      _query,
      _runSearch,
      time: const Duration(milliseconds: 400),
    );
  }

  void _runSearch(String query) {
    _searchRuns.value++;
    final String needle = query.trim().toLowerCase();
    final List<String> matches = needle.isEmpty
        ? _catalog
        : _catalog.where((String item) => item.contains(needle)).toList();
    _results
      ..clear()
      ..addAll(matches);
  }

  @override
  void dispose() {
    _debounceWorker.dispose();
    _controller.dispose();
    _query.close();
    _results.close();
    _searchRuns.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _controller,
            decoration: const InputDecoration(
              labelText: 'Search fruit',
              border: OutlineInputBorder(),
            ),
            onChanged: _query.setValue,
          ),
          const SizedBox(height: 8),
          Observer(
            () => Text(
              'Real searches run: ${_searchRuns.value} '
              '(typing fast coalesces into one, 400ms after you stop)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Observer(
              () => ListView.builder(
                itemCount: _results.length,
                itemBuilder: (context, index) =>
                    ListTile(title: Text(_results[index])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
