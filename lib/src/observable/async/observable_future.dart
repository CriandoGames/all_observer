import '../observable.dart';
import 'async_state.dart';

/// An [Observable] wrapping a `Future`-producing operation, exposing its
/// current [AsyncState] (loading/data/error) as its `value`. This is a
/// Rx-style observable value carrying an async loading/data/error state, a
/// pattern found in various asynchronous state-management approaches,
/// implemented here directly on top of [Observable] — no `Stream` involved.
///
/// By default the operation starts automatically when the instance is
/// created (`autoStart: true`). Call [refresh] to re-run it later (e.g. a
/// pull-to-refresh or a retry button); [refresh] is just a more
/// intention-revealing alias for [run].
///
/// **Race safety**: every call to [run] bumps an internal generation
/// counter. If [futureFactory] is invoked again (a newer [run]) before an
/// older one finishes, the older call's result — whether success or error —
/// is silently discarded when it eventually arrives, instead of
/// overwriting the newer state. The same guard also discards a still
/// in-flight result if [close] was called in the meantime.
///
/// Um [Observable] que envolve uma operação que produz uma `Future`,
/// expondo seu [AsyncState] atual (carregando/dados/erro) como seu `value`.
/// Este é um padrão de valor observável estilo Rx carregando um estado
/// assíncrono de carregando/dados/erro, encontrado em diversas abordagens
/// de gerenciamento de estado assíncrono, implementado aqui diretamente
/// sobre [Observable] — nenhum `Stream` envolvido.
///
/// Por padrão a operação inicia automaticamente na criação da instância
/// (`autoStart: true`). Chame [refresh] para executá-la novamente depois
/// (ex.: um pull-to-refresh ou um botão de tentar novamente); [refresh] é
/// apenas um alias mais expressivo para [run].
///
/// **Segurança contra corrida**: toda chamada a [run] incrementa um
/// contador interno de geração. Se [futureFactory] for invocado novamente
/// (um [run] mais novo) antes de uma chamada anterior terminar, o
/// resultado dessa chamada mais antiga — sucesso ou erro — é
/// silenciosamente descartado quando finalmente chegar, em vez de
/// sobrescrever o estado mais novo. A mesma proteção também descarta um
/// resultado ainda em andamento se [close] tiver sido chamado nesse meio
/// tempo.
///
/// Example / Exemplo:
/// ```dart
/// final userFuture = ObservableFuture<User>(() => api.fetchUser(id));
/// Observer(() => userFuture.value.when(
///   loading: (previousData) => const CircularProgressIndicator(),
///   data: (user) => Text(user.name),
///   error: (error, stackTrace) => Text('Error: $error'),
/// ));
/// userFuture.refresh(); // re-runs futureFactory
/// ```
class ObservableFuture<T> extends Observable<AsyncState<T>> {
  /// Creates an [ObservableFuture] running [futureFactory]. When
  /// [autoStart] is `true` (the default), [run] is invoked immediately;
  /// pass `false` to build the instance without starting, and call [run]
  /// manually when ready.
  ///
  /// Cria um [ObservableFuture] executando [futureFactory]. Quando
  /// [autoStart] for `true` (padrão), [run] é invocado imediatamente; passe
  /// `false` para construir a instância sem iniciar, e chame [run]
  /// manualmente quando estiver pronto.
  ObservableFuture(this.futureFactory, {bool autoStart = true, String? name})
    : super(AsyncLoading<T>(), name: name) {
    if (autoStart) {
      run();
    }
  }

  /// Produces the `Future` this instance tracks. Invoked once per [run]/
  /// [refresh] call.
  ///
  /// Produz a `Future` que esta instância acompanha. Invocado uma vez por
  /// chamada a [run]/[refresh].
  final Future<T> Function() futureFactory;

  int _generation = 0;

  T? _previousDataFromCurrent() {
    final AsyncState<T> current = value;
    return switch (current) {
      AsyncData<T>(:final T value) => value,
      AsyncLoading<T>(:final T? previousData) => previousData,
      AsyncError<T>() => null,
    };
  }

  /// Runs [futureFactory] and updates [value] through the loading → data/
  /// error lifecycle. Any previous [AsyncData] value is preserved as
  /// [AsyncLoading.previousData] while this run is in flight. If [run] is
  /// called again before a previous run completes, the stale data carried
  /// in the intermediate [AsyncLoading] state is also propagated, so the
  /// `previousData` is never silently lost across multiple rapid refreshes.
  ///
  /// Safe to call while a previous run is still in flight: the previous
  /// run's eventual result (success or error) is discarded when it arrives,
  /// since it is no longer the newest one. Also safe to call after [close]
  /// — the resulting state is simply never written, since writes to a
  /// closed [Observable] are already a no-op.
  ///
  /// Executa [futureFactory] e atualiza [value] pelo ciclo de vida
  /// carregando → dados/erro. Qualquer [AsyncData] anterior é preservado
  /// como [AsyncLoading.previousData] enquanto esta execução está em
  /// andamento. Se [run] for chamado novamente antes de uma execução
  /// anterior terminar, o dado desatualizado carregado no estado
  /// [AsyncLoading] intermediário também é propagado, para que o
  /// `previousData` nunca seja silenciosamente perdido em múltiplos
  /// refreshes rápidos.
  ///
  /// Seguro chamar enquanto uma execução anterior ainda está em andamento:
  /// o resultado eventual dessa execução anterior (sucesso ou erro) é
  /// descartado quando chegar, já que não é mais o mais recente. Também
  /// seguro chamar após [close] — o estado resultante simplesmente nunca é
  /// escrito, já que escritas em um [Observable] fechado já são um no-op.
  Future<void> run() async {
    if (isClosed) {
      return;
    }
    final int generation = ++_generation;
    value = AsyncLoading<T>(previousData: _previousDataFromCurrent());
    try {
      final T result = await futureFactory();
      if (generation != _generation || isClosed) {
        return;
      }
      value = AsyncData<T>(result);
    } catch (error, stackTrace) {
      if (generation != _generation || isClosed) {
        return;
      }
      value = AsyncError<T>(error, stackTrace);
    }
  }

  /// Alias for [run], for call sites where "refresh" better expresses
  /// intent (pull-to-refresh, a retry button).
  ///
  /// Alias para [run], para pontos de uso em que "refresh" expressa melhor
  /// a intenção (pull-to-refresh, um botão de tentar novamente).
  @override
  Future<void> refresh() => run();
}
