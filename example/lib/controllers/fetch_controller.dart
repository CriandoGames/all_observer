import 'dart:math';

import 'package:all_observer/all_observer.dart';

/// Business logic for [AsyncDemo]: wraps an [ObservableFuture] around an
/// injectable fetch function, so tests can substitute a fake/controlled
/// `Future` instead of the demo's random-delay simulation.
///
/// Lógica de negócio de [AsyncDemo]: envolve um [ObservableFuture] em torno
/// de uma função de busca injetável, para que os testes possam substituir
/// uma `Future` falsa/controlada em vez da simulação de atraso aleatório do
/// demo.
class FetchController {
  /// Creates a controller running [fetcher] (defaults to a simulated
  /// network call with a 1s delay and ~30% failure chance).
  ///
  /// Cria um controller executando [fetcher] (padrão: uma chamada de rede
  /// simulada com 1s de atraso e ~30% de chance de falha).
  FetchController({Future<int> Function()? fetcher})
    : fetch = ObservableFuture<int>(fetcher ?? _simulateFetch);

  static final Random _random = Random();

  static Future<int> _simulateFetch() async {
    await Future<void>.delayed(const Duration(seconds: 1));
    if (_random.nextDouble() < 0.3) {
      throw Exception('Simulated network failure');
    }
    return _random.nextInt(1000);
  }

  /// The tracked async operation.
  ///
  /// A operação assíncrona rastreada.
  final ObservableFuture<int> fetch;

  /// Re-runs the fetch (pull-to-refresh / retry).
  ///
  /// Executa a busca novamente (pull-to-refresh / tentar novamente).
  Future<void> retry() => fetch.refresh();

  /// Releases the underlying observable. Call from `State.dispose()`.
  ///
  /// Libera o observável subjacente. Chame a partir de `State.dispose()`.
  void dispose() => fetch.close();
}
