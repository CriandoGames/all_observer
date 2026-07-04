import 'dart:math';

import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

/// Demo 3: `ObservableFuture` simulating a network fetch with an artificial
/// delay and a random chance of failure, rendered through `when(loading:
/// data: error:)`, plus a retry button and a stale-while-loading readout
/// via `AsyncLoading.previousData`.
///
/// Demo 3: `ObservableFuture` simulando uma busca de rede com atraso
/// artificial e chance aleatória de falha, renderizada via `when(loading:
/// data: error:)`, mais um botão de tentar novamente e uma leitura do tipo
/// stale-while-loading via `AsyncLoading.previousData`.
class AsyncDemo extends StatefulWidget {
  /// Creates the async demo.
  ///
  /// Cria o demo assíncrono.
  const AsyncDemo({super.key});

  @override
  State<AsyncDemo> createState() => _AsyncDemoState();
}

class _AsyncDemoState extends State<AsyncDemo> {
  final Random _random = Random();
  late final ObservableFuture<int> _fetch;

  Future<int> _simulateFetch() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_random.nextDouble() < 0.3) {
      throw Exception('Simulated network failure');
    }
    return _random.nextInt(1000);
  }

  @override
  void initState() {
    super.initState();
    _fetch = ObservableFuture<int>(_simulateFetch);
  }

  @override
  void dispose() {
    _fetch.close();
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
            () => _fetch.value.when(
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
            onPressed: _fetch.refresh,
            child: const Text('Retry / Refresh'),
          ),
        ],
      ),
    );
  }
}
