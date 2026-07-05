/// Optional integration point for persisting and restoring the value of an
/// [Observable] against some external storage — implemented by a bridge
/// package (e.g. `all_box`) that knows how to read/write/serialize [T], not
/// by `all_observer` itself, which stays free of any I/O, serialization, or
/// storage dependency.
///
/// `all_observer` never implements or requires this interface: it's a shape
/// a separate package can conform to (a key-value box, secure storage, a
/// single row in a local database, a `SharedPreferences` wrapper, ...), so
/// that storage can be wired to an [Observable] via
/// `ObservableStoreBinding.persistWith` (in
/// `package:all_observer/all_observer.dart`), without `all_observer` ever
/// depending on how that storage works. Deliberately synchronous — real
/// backends that need an async open/init step should perform it before
/// constructing the [ObservableStore] (and before constructing the
/// [Observable] it will be bound to), the same way `SharedPreferences`
/// itself is awaited once at startup and then read/written synchronously.
///
/// Ponto de integração opcional para persistir e restaurar o valor de um
/// [Observable] contra algum armazenamento externo — implementado por um
/// pacote ponte (ex.: `all_box`) que sabe ler/escrever/serializar [T], não
/// pelo próprio `all_observer`, que permanece livre de qualquer dependência
/// de I/O, serialização ou armazenamento.
///
/// O `all_observer` nunca implementa nem exige esta interface: é um formato
/// que um pacote separado pode seguir (uma box chave-valor, armazenamento
/// seguro, uma única linha em um banco local, um wrapper de
/// `SharedPreferences`, ...), para que esse armazenamento possa ser
/// conectado a um [Observable] via `ObservableStoreBinding.persistWith` (em
/// `package:all_observer/all_observer.dart`), sem que o `all_observer`
/// jamais dependa de como esse armazenamento funciona. Deliberadamente
/// síncrono — backends reais que precisem de um passo assíncrono de
/// abertura/inicialização devem executá-lo antes de construir o
/// [ObservableStore] (e antes de construir o [Observable] ao qual ele será
/// vinculado), da mesma forma que o próprio `SharedPreferences` é aguardado
/// uma vez na inicialização e depois lido/escrito de forma síncrona.
abstract interface class ObservableStore<T> {
  /// Reads the last persisted value, or `null` if none exists yet (e.g. the
  /// very first run, or after [delete]).
  ///
  /// Lê o último valor persistido, ou `null` se nenhum existir ainda (ex.:
  /// a primeiríssima execução, ou depois de [delete]).
  T? read();

  /// Persists [value], replacing whatever was previously stored.
  ///
  /// Persiste [value], substituindo o que estava armazenado anteriormente.
  void write(T value);

  /// Removes any persisted value, so a subsequent [read] returns `null`.
  ///
  /// Remove qualquer valor persistido, de forma que uma [read] subsequente
  /// retorne `null`.
  void delete();
}
