/// Represents the three possible states of an asynchronous operation: in
/// progress ([AsyncLoading]), completed with a value ([AsyncData]), or
/// completed with an error ([AsyncError]). Consumed via [when]/[maybeWhen]
/// or the [isLoading]/[hasData]/[hasError]/[valueOrNull] getters.
///
/// This is a common loading/data/error pattern found across many
/// asynchronous UI approaches, expressed here as a plain sealed class with
/// no `Stream`/`Future`-specific machinery of its own — [ObservableFuture]
/// is what actually drives it from a `Future`.
///
/// Representa os três estados possíveis de uma operação assíncrona: em
/// andamento ([AsyncLoading]), concluída com um valor ([AsyncData]), ou
/// concluída com um erro ([AsyncError]). Consumido via [when]/[maybeWhen]
/// ou pelos getters [isLoading]/[hasData]/[hasError]/[valueOrNull].
///
/// Este é um padrão comum de carregando/dados/erro encontrado em diversas
/// abordagens de UI assíncrona, expresso aqui como uma classe sealed simples
/// sem nenhum maquinário próprio de `Stream`/`Future` — quem de fato o
/// conduz a partir de um `Future` é o [ObservableFuture].
///
/// Example / Exemplo:
/// ```dart
/// Widget build(BuildContext context) {
///   return state.when(
///     loading: (previousData) => const CircularProgressIndicator(),
///     data: (value) => Text('$value'),
///     error: (error, stackTrace) => Text('Error: $error'),
///   );
/// }
/// ```
sealed class AsyncState<T> {
  const AsyncState();

  /// Whether this state is [AsyncLoading].
  ///
  /// Se este estado é [AsyncLoading].
  bool get isLoading => this is AsyncLoading<T>;

  /// Whether this state is [AsyncData].
  ///
  /// Se este estado é [AsyncData].
  bool get hasData => this is AsyncData<T>;

  /// Whether this state is [AsyncError].
  ///
  /// Se este estado é [AsyncError].
  bool get hasError => this is AsyncError<T>;

  /// The value if this state is [AsyncData], otherwise `null`. For
  /// [AsyncLoading], this is `null` even if [AsyncLoading.previousData] is
  /// set — use [AsyncLoading.previousData] directly for a
  /// stale-while-loading read.
  ///
  /// O valor se este estado for [AsyncData], caso contrário `null`. Para
  /// [AsyncLoading], isto é `null` mesmo que [AsyncLoading.previousData]
  /// esteja definido — use [AsyncLoading.previousData] diretamente para uma
  /// leitura do tipo stale-while-loading.
  T? get valueOrNull => switch (this) {
    AsyncData<T>(value: final T value) => value,
    _ => null,
  };

  /// Pattern-matches over every case, requiring a handler for each.
  ///
  /// Faz pattern-matching sobre todos os casos, exigindo um handler para
  /// cada um.
  R when<R>({
    required R Function(T? previousData) loading,
    required R Function(T value) data,
    required R Function(Object error, StackTrace stackTrace) error,
  }) {
    return switch (this) {
      AsyncLoading<T>(previousData: final T? previousData) => loading(
        previousData,
      ),
      AsyncData<T>(value: final T value) => data(value),
      AsyncError<T>(error: final Object e, stackTrace: final StackTrace st) =>
        error(e, st),
    };
  }

  /// Pattern-matches with optional handlers, falling back to [orElse] for
  /// any case not provided.
  ///
  /// Faz pattern-matching com handlers opcionais, recorrendo a [orElse]
  /// para qualquer caso não fornecido.
  R maybeWhen<R>({
    R Function(T? previousData)? loading,
    R Function(T value)? data,
    R Function(Object error, StackTrace stackTrace)? error,
    required R Function() orElse,
  }) {
    final AsyncState<T> self = this;
    return switch (self) {
      AsyncLoading<T>(previousData: final T? previousData) =>
        loading?.call(previousData) ?? orElse(),
      AsyncData<T>(value: final T value) => data?.call(value) ?? orElse(),
      AsyncError<T>(error: final Object e, stackTrace: final StackTrace st)
          when error != null =>
        error(e, st),
      _ => orElse(),
    };
  }
}

/// The operation is in progress. [previousData] optionally carries the last
/// known [AsyncData] value (a "stale-while-loading" read), so a UI can keep
/// showing the previous content dimmed/overlaid instead of a blank spinner
/// on a refresh.
///
/// A operação está em andamento. [previousData] opcionalmente carrega o
/// último valor conhecido de [AsyncData] (uma leitura do tipo
/// stale-while-loading), para que uma UI possa continuar mostrando o
/// conteúdo anterior esmaecido/sobreposto em vez de um spinner em branco
/// durante um refresh.
final class AsyncLoading<T> extends AsyncState<T> {
  /// Creates a loading state, optionally carrying the [previousData].
  ///
  /// Cria um estado de carregamento, opcionalmente carregando
  /// [previousData].
  const AsyncLoading({this.previousData});

  /// The last known value, if any, from before this loading state started.
  ///
  /// O último valor conhecido, se houver, antes deste estado de
  /// carregamento começar.
  final T? previousData;

  @override
  bool operator ==(Object other) =>
      other is AsyncLoading<T> && other.previousData == previousData;

  @override
  int get hashCode => Object.hash(AsyncLoading<T>, previousData);

  @override
  String toString() => 'AsyncLoading<$T>(previousData: $previousData)';
}

/// The operation completed successfully with [value].
///
/// A operação foi concluída com sucesso, com [value].
final class AsyncData<T> extends AsyncState<T> {
  /// Creates a data state holding [value].
  ///
  /// Cria um estado de dados contendo [value].
  const AsyncData(this.value);

  /// The successfully produced value.
  ///
  /// O valor produzido com sucesso.
  final T value;

  @override
  bool operator ==(Object other) =>
      other is AsyncData<T> && other.value == value;

  @override
  int get hashCode => Object.hash(AsyncData<T>, value);

  @override
  String toString() => 'AsyncData<$T>($value)';
}

/// The operation completed with [error] and [stackTrace].
///
/// A operação foi concluída com [error] e [stackTrace].
final class AsyncError<T> extends AsyncState<T> {
  /// Creates an error state.
  ///
  /// Cria um estado de erro.
  const AsyncError(this.error, this.stackTrace);

  /// The error object thrown by the operation.
  ///
  /// O objeto de erro lançado pela operação.
  final Object error;

  /// The stack trace captured alongside [error].
  ///
  /// O stack trace capturado junto de [error].
  final StackTrace stackTrace;

  @override
  bool operator ==(Object other) =>
      other is AsyncError<T> &&
      other.error == error &&
      other.stackTrace == stackTrace;

  @override
  int get hashCode => Object.hash(AsyncError<T>, error, stackTrace);

  @override
  String toString() => 'AsyncError<$T>($error)';
}

/// Alias for [AsyncState], matching the `AsyncValue` name used by other
/// loading/data/error patterns in the ecosystem, for readers coming from
/// that vocabulary. Purely a naming convenience — identical type, so
/// `AsyncValue<T>` and `AsyncState<T>` are interchangeable everywhere
/// (including in `switch`/`when` patterns).
///
/// Alias para [AsyncState], espelhando o nome `AsyncValue` usado por outros
/// padrões de carregando/dados/erro no ecossistema, para quem já vem
/// familiarizado com esse vocabulário. Puramente uma conveniência de nome —
/// tipo idêntico, então `AsyncValue<T>` e `AsyncState<T>` são
/// intercambiáveis em qualquer lugar (inclusive em padrões `switch`/`when`).
typedef AsyncValue<T> = AsyncState<T>;
