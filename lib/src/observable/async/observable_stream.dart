import 'dart:async';

import '../../core/core_error_reporting.dart';
import '../observable.dart';
import 'async_state.dart';

/// An [Observable] wrapping a `Stream`-producing operation, exposing its
/// current [AsyncState] (loading/data/error) as its `value` — the `Stream`
/// counterpart of `ObservableFuture`. Every event the stream emits becomes
/// an [AsyncData] update; a `Stream` error becomes [AsyncError].
///
/// By default the stream is subscribed to automatically when the instance
/// is created (`autoStart: true`). Call [refresh] to cancel the current
/// subscription and start a fresh one from [streamFactory] (e.g. to
/// reconnect a socket/polling stream after an error, or a pull-to-refresh).
///
/// **Race safety**: every call to [run]/[refresh] bumps an internal
/// generation counter and cancels the previous `StreamSubscription` before
/// subscribing again. Any event still in flight from a just-cancelled
/// subscription (a race between `cancel()` and an event already queued in
/// the event loop) is discarded when it arrives, instead of overwriting the
/// newer state — the same principle `ObservableFuture` uses for `Future`s.
/// [close] also cancels the active subscription.
///
/// Um [Observable] que envolve uma operação que produz uma `Stream`,
/// expondo seu [AsyncState] atual (carregando/dados/erro) como seu `value`
/// — o equivalente em `Stream` de `ObservableFuture`. Todo evento emitido
/// pela stream vira uma atualização [AsyncData]; um erro da `Stream` vira
/// [AsyncError].
///
/// Por padrão a stream é assinada automaticamente na criação da instância
/// (`autoStart: true`). Chame [refresh] para cancelar a assinatura atual e
/// iniciar uma nova a partir de [streamFactory] (ex.: reconectar uma stream
/// de socket/polling após um erro, ou um pull-to-refresh).
///
/// **Segurança contra corrida**: toda chamada a [run]/[refresh] incrementa
/// um contador interno de geração e cancela a `StreamSubscription` anterior
/// antes de assinar novamente. Qualquer evento ainda em trânsito de uma
/// assinatura recém-cancelada (uma corrida entre `cancel()` e um evento já
/// enfileirado no event loop) é descartado quando chega, em vez de
/// sobrescrever o estado mais novo — mesmo princípio que `ObservableFuture`
/// usa para `Future`s. [close] também cancela a assinatura ativa.
///
/// Example / Exemplo:
/// ```dart
/// final ticks = ObservableStream<int>(
///   () => Stream.periodic(const Duration(seconds: 1), (i) => i),
/// );
/// Observer(() => ticks.value.when(
///   loading: (previousData) => const CircularProgressIndicator(),
///   data: (n) => Text('$n'),
///   error: (error, stackTrace) => Text('Error: $error'),
/// ));
/// ticks.close(); // cancels the subscription
/// ```
class ObservableStream<T> extends Observable<AsyncState<T>> {
  /// Creates an [ObservableStream] subscribing to [streamFactory]'s result.
  /// When [autoStart] is `true` (the default), [run] is invoked
  /// immediately; pass `false` to build the instance without subscribing,
  /// and call [run] manually when ready. [cancelOnError] mirrors
  /// `Stream.listen`'s parameter of the same name (default `false`): the
  /// underlying subscription is not auto-cancelled by the `Stream` itself
  /// on error, so it can keep emitting after an [AsyncError] update, the
  /// same way a raw `stream.listen(..., cancelOnError: false)` would.
  ///
  /// Cria um [ObservableStream] assinando o resultado de [streamFactory].
  /// Quando [autoStart] for `true` (padrão), [run] é invocado imediatamente;
  /// passe `false` para construir a instância sem assinar, e chame [run]
  /// manualmente quando estiver pronto. [cancelOnError] espelha o parâmetro
  /// de mesmo nome de `Stream.listen` (padrão `false`): a assinatura
  /// subjacente não é auto-cancelada pela própria `Stream` em caso de erro,
  /// então pode continuar emitindo após uma atualização [AsyncError], da
  /// mesma forma que um `stream.listen(..., cancelOnError: false)` bruto
  /// faria.
  ObservableStream(
    this.streamFactory, {
    bool autoStart = true,
    bool cancelOnError = false,
    String? name,
  }) : _cancelOnError = cancelOnError,
       super(AsyncLoading<T>(), name: name) {
    if (autoStart) {
      run();
    }
  }

  /// Produces the `Stream` this instance subscribes to. Invoked once per
  /// [run]/[refresh] call.
  ///
  /// Produz a `Stream` que esta instância assina. Invocado uma vez por
  /// chamada a [run]/[refresh].
  final Stream<T> Function() streamFactory;

  final bool _cancelOnError;

  int _generation = 0;
  StreamSubscription<T>? _subscription;

  void _cancelSubscription(
    StreamSubscription<T>? subscription, {
    required String context,
  }) {
    if (subscription == null) {
      return;
    }
    unawaited(
      subscription.cancel().catchError((Object error, StackTrace stackTrace) {
        CoreErrorReporting.report(
          error,
          stackTrace,
          library: 'all_observer',
          context: context,
        );
      }),
    );
  }

  T? _previousDataFromCurrent() {
    final AsyncState<T> current = value;
    return switch (current) {
      AsyncData<T>(:final T value) => value,
      AsyncLoading<T>(:final T? previousData) => previousData,
      AsyncError<T>() => null,
    };
  }

  /// Cancels the current subscription (if any) and subscribes afresh to
  /// [streamFactory], updating [value] through the loading → data/error
  /// lifecycle as events arrive. Any previous [AsyncData] value is
  /// preserved as [AsyncLoading.previousData] while the new subscription
  /// warms up.
  ///
  /// Safe to call while a previous subscription is still active: it is
  /// cancelled first (fire-and-forget — [run] does not wait for `cancel()`
  /// to complete, since the generation guard already makes any of its
  /// straggling events a no-op), and any event of the old subscription
  /// still queued in the event loop is discarded when it arrives, since it
  /// is no longer the newest generation. Also safe to call after [close] —
  /// the resulting state is simply never written, since writes to a closed
  /// [Observable] are already a no-op.
  ///
  /// Cancela a assinatura atual (se houver) e assina novamente a partir de
  /// [streamFactory], atualizando [value] pelo ciclo de vida carregando →
  /// dados/erro conforme os eventos chegam. Qualquer [AsyncData] anterior é
  /// preservado como [AsyncLoading.previousData] enquanto a nova assinatura
  /// aquece.
  ///
  /// Seguro chamar enquanto uma assinatura anterior ainda está ativa: ela é
  /// cancelada primeiro (fire-and-forget — [run] não espera o `cancel()`
  /// terminar, já que a proteção por geração já torna qualquer evento
  /// atrasado dela um no-op), e qualquer evento da assinatura antiga ainda
  /// enfileirado no event loop é descartado quando chegar, já que não é mais
  /// a geração mais recente. Também seguro chamar após [close] — o estado
  /// resultante simplesmente nunca é escrito, já que escritas em um
  /// [Observable] fechado já são um no-op.
  void run() {
    final int generation = ++_generation;
    _cancelSubscription(
      _subscription,
      context: 'failed to cancel the previous ObservableStream subscription',
    );
    _subscription = null;
    value = AsyncLoading<T>(previousData: _previousDataFromCurrent());
    late final Stream<T> stream;
    try {
      stream = streamFactory();
    } catch (error, stackTrace) {
      if (generation == _generation && !isClosed) {
        value = AsyncError<T>(error, stackTrace);
      }
      return;
    }
    _subscription = stream.listen(
      (T event) {
        if (generation != _generation || isClosed) {
          return;
        }
        value = AsyncData<T>(event);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (generation != _generation || isClosed) {
          return;
        }
        value = AsyncError<T>(error, stackTrace);
      },
      cancelOnError: _cancelOnError,
    );
  }

  /// Alias for [run], for call sites where "refresh" better expresses
  /// intent (reconnect, retry).
  ///
  /// Alias para [run], para pontos de uso em que "refresh" expressa melhor
  /// a intenção (reconectar, tentar novamente).
  @override
  void refresh() => run();

  /// Cancels the active subscription (if any) before disposing, in addition
  /// to `Observable.close`'s usual listener cleanup.
  ///
  /// Cancela a assinatura ativa (se houver) antes de descartar, além da
  /// limpeza usual de listeners de `Observable.close`.
  @override
  void close() {
    _generation++; // invalidates any straggling event before cancel() settles
    _cancelSubscription(
      _subscription,
      context: 'failed to cancel ObservableStream during close',
    );
    _subscription = null;
    super.close();
  }
}
