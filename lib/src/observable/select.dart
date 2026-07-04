import 'computed.dart';
import 'observable.dart';

/// Sugar for deriving a narrower [Computed] from a single [Observable],
/// so an [Observer] (or another [Computed]) that only cares about part of
/// a larger value can depend on just that part instead of the whole
/// [Observable].
///
/// Açúcar sintático para derivar um [Computed] mais estreito a partir de um
/// único [Observable], para que um [Observer] (ou outro [Computed]) que se
/// importa apenas com parte de um valor maior possa depender só daquela
/// parte, em vez do [Observable] inteiro.
extension ObservableSelectExtension<T> on Observable<T> {
  /// Returns a [Computed] that recomputes to `selector(value)` whenever
  /// this [Observable] changes, exactly equivalent to writing
  /// `Computed(() => selector(observable.value), name: name)` by hand.
  ///
  /// Like any [Computed], the result is lazy and memoized, and only
  /// notifies its own listeners when the selected result actually differs
  /// — so changing a field this [selector] doesn't read (via [refresh], or
  /// a field write on a larger object) causes no downstream rebuild.
  ///
  /// The caller owns the returned [Computed] and is responsible for
  /// calling [Computed.close] on it when done — [select] does not
  /// associate the result's lifetime with this [Observable]'s in any way.
  ///
  /// Retorna um [Computed] que recalcula para `selector(value)` sempre que
  /// este [Observable] mudar, exatamente equivalente a escrever
  /// `Computed(() => selector(observable.value), name: name)` manualmente.
  ///
  /// Como todo [Computed], o resultado é preguiçoso e memoizado, e só
  /// notifica seus próprios listeners quando o resultado selecionado
  /// realmente difere — então alterar um campo que este [selector] não lê
  /// (via [refresh], ou uma escrita de campo em um objeto maior) não causa
  /// rebuild a jusante.
  ///
  /// Quem chama é dono do [Computed] retornado e é responsável por chamar
  /// [Computed.close] nele quando terminar — [select] não associa o tempo
  /// de vida do resultado ao deste [Observable] de forma alguma.
  ///
  /// Example / Exemplo:
  /// ```dart
  /// final user = Observable<User>(User(name: 'Carlos', age: 30));
  /// final userName = user.select((u) => u.name);
  /// Observer(() => Text(userName.value)); // ignores age-only changes
  /// // ...
  /// userName.close();
  /// ```
  Computed<R> select<R>(R Function(T value) selector, {String? name}) {
    return Computed<R>(() => selector(value), name: name);
  }
}
