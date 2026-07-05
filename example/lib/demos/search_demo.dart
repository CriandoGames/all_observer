import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

import '../controllers/search_controller.dart';

/// Demo 2: a `TextField` feeding an `Observable<String>` query, debounced
/// 400ms via the `debounce` worker, filtering an `ObservableList` of
/// results.
///
/// The controller is created internally by default, but can be injected —
/// see `example/test/worker_debounce_test.dart`, which injects a shorter
/// debounce window and a small fixed catalog for deterministic assertions.
///
/// Demo 2: um `TextField` alimentando uma query `Observable<String>`,
/// debounced em 400ms via o worker `debounce`, filtrando uma
/// `ObservableList` de resultados.
class SearchDemo extends StatefulWidget {
  /// Creates the debounced search demo. Pass [controller] to inject one
  /// (e.g. from a test); otherwise a fresh [FruitSearchController] is
  /// created and owned internally.
  ///
  /// Cria o demo de busca com debounce. Passe [controller] para injetar um
  /// (ex.: a partir de um teste); caso contrário, um novo
  /// [FruitSearchController] é criado e possuído internamente.
  const SearchDemo({super.key, this.controller});

  /// An optional externally-owned controller. When provided, this widget
  /// does NOT dispose it.
  ///
  /// Um controller opcional possuído externamente. Quando fornecido, este
  /// widget NÃO o descarta.
  final FruitSearchController? controller;

  @override
  State<SearchDemo> createState() => _SearchDemoState();
}

class _SearchDemoState extends State<SearchDemo> {
  late final FruitSearchController _controller;
  late final bool _ownsController;
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? FruitSearchController();
  }

  @override
  void dispose() {
    _textController.dispose();
    if (_ownsController) {
      _controller.dispose();
    }
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
            controller: _textController,
            decoration: const InputDecoration(
              labelText: 'Search fruit',
              border: OutlineInputBorder(),
            ),
            onChanged: _controller.query.setValue,
          ),
          const SizedBox(height: 8),
          Observer(
            () => Text(
              'Real searches run: ${_controller.searchRuns.value} '
              '(typing fast coalesces into one, 400ms after you stop)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Observer(
              () => ListView.builder(
                itemCount: _controller.results.length,
                itemBuilder: (context, index) =>
                    ListTile(title: Text(_controller.results[index])),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
