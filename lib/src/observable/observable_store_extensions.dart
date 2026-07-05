import '../core/observable_store.dart';
import '../core/typedefs.dart';
import 'observable.dart';

/// Binds an [Observable] to an [ObservableStore], so its value survives
/// across app restarts through whatever [store] wraps.
///
/// Vincula um [Observable] a um [ObservableStore], para que seu valor
/// sobreviva a reinícios do app através do que [store] envolve.
extension ObservableStoreBinding<T> on Observable<T> {
  /// Restores this [Observable]'s value from [store] immediately (if
  /// [store] has a persisted value — i.e. `store.read()` returns
  /// non-`null`), then persists every subsequent value change back to
  /// [store] via [store]`.write`. Returns a [Disposer] that stops the
  /// persistence (call it, typically, from `ObserverStateMixin.autoDispose`
  /// or your own `dispose()`) without touching the [Observable] itself —
  /// it keeps working as a normal, unpersisted [Observable] afterward.
  ///
  /// This only restores once, at the moment [persistWith] is called — it
  /// does not watch [store] for external changes. If [store]'s persisted
  /// value can legitimately be `T`'s own "empty"/default value and that's
  /// different from "nothing persisted yet", use a nullable `T?`
  /// [Observable] (`Observable<T?>`) so [ObservableStore.read] returning
  /// `null` is unambiguous.
  ///
  /// Restaura o valor deste [Observable] a partir de [store] imediatamente
  /// (se [store] tiver um valor persistido — ou seja, `store.read()`
  /// retornar não-`null`), depois persiste toda mudança de valor
  /// subsequente de volta em [store] via [store]`.write`. Retorna um
  /// [Disposer] que interrompe a persistência (chame-o, tipicamente, a
  /// partir de `ObserverStateMixin.autoDispose` ou do seu próprio
  /// `dispose()`) sem mexer no [Observable] em si — ele continua
  /// funcionando como um [Observable] normal, não persistido, depois disso.
  ///
  /// Isto só restaura uma vez, no momento em que [persistWith] é chamado —
  /// não observa [store] em busca de mudanças externas. Se o valor
  /// persistido de [store] puder legitimamente ser o valor "vazio"/padrão
  /// do próprio `T`, e isso for diferente de "nada persistido ainda", use
  /// um [Observable] anulável (`Observable<T?>`) para que o retorno `null`
  /// de [ObservableStore.read] seja inequívoco.
  ///
  /// Example / Exemplo:
  /// ```dart
  /// final theme = Observable<String>('light');
  /// final dispose = theme.persistWith(myThemeStore);
  /// // ...
  /// dispose(); // stop persisting; `theme` keeps working normally.
  /// ```
  Disposer persistWith(ObservableStore<T> store) {
    final T? restored = store.read();
    if (restored != null) {
      value = restored;
    }
    final Disposer dispose = listen((T v) => store.write(v)).cancel;
    return dispose;
  }
}
