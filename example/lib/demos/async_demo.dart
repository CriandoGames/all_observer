import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

import '../controllers/fetch_controller.dart';

/// Demo 3: `ObservableFuture` simulating a network fetch with an artificial
/// delay and a random chance of failure, rendered through `when(loading:
/// data: error:)`, plus a retry button and a stale-while-loading readout
/// via `AsyncLoading.previousData`.
///
/// The controller is created internally by default, but can be injected —
/// see `example/test/observable_future_test.dart`, which injects a fake
/// fetcher backed by a `Completer` for deterministic loading/data/error
/// assertions.
///
/// Demo 3: `ObservableFuture` simulando uma busca de rede com atraso
/// artificial e chance aleatória de falha, renderizada via `when(loading:
/// data: error:)`, mais um botão de tentar novamente e uma leitura do tipo
/// stale-while-loading via `AsyncLoading.previousData`.
class AsyncDemo extends StatefulWidget {
  /// Creates the async demo. Pass [controller] to inject one (e.g. from a
  /// test); otherwise a fresh [FetchController] (simulated network call) is
  /// created and owned internally.
  ///
  /// Cria o demo assíncrono. Passe [controller] para injetar um (ex.: a
  /// partir de um teste); caso contrário, um novo [FetchController] (chamada
  /// de rede simulada) é criado e possuído internamente.
  const AsyncDemo({super.key, this.controller});

  /// An optional externally-owned controller. When provided, this widget
  /// does NOT dispose it.
  ///
  /// Um controller opcional possuído externamente. Quando fornecido, este
  /// widget NÃO o descarta.
  final FetchController? controller;

  @override
  State<AsyncDemo> createState() => _AsyncDemoState();
}

class _AsyncDemoState extends State<AsyncDemo> {
  late final FetchController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    _controller = widget.controller ?? FetchController();
  }

  @override
  void dispose() {
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
          const Text(
            'Simulates a fetch with a 1s delay and ~30% failure chance.',
          ),
          const SizedBox(height: 16),
          Observer(
            () => _controller.fetch.value.when(
              loading: (int? previousData) => Row(
                children: <Widget>[
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    previousData == null
                        ? 'Loading...'
                        : 'Refreshing (last value: $previousData)...',
                  ),
                ],
              ),
              data: (int value) => Text(
                'Loaded: $value',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              error: (Object error, StackTrace stackTrace) => Text(
                'Error: $error',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: _controller.retry,
            child: const Text('Retry / Refresh'),
          ),
        ],
      ),
    );
  }
}
