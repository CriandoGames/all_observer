import 'collections/observable_list.dart';
import 'collections/observable_map.dart';
import 'collections/observable_set.dart';
import 'observable.dart';
import 'observable_types.dart';

/// Creates an [ObservableInt] from an `int` literal or value.
///
/// Cria um [ObservableInt] a partir de um literal ou valor `int`.
extension ObservableIntExtension on int {
  /// Wraps this value in an [ObservableInt].
  ///
  /// Envolve este valor em um [ObservableInt].
  ObservableInt get obs => ObservableInt(this);
}

/// Creates an [ObservableDouble] from a `double` literal or value.
///
/// Cria um [ObservableDouble] a partir de um literal ou valor `double`.
extension ObservableDoubleExtension on double {
  /// Wraps this value in an [ObservableDouble].
  ///
  /// Envolve este valor em um [ObservableDouble].
  ObservableDouble get obs => ObservableDouble(this);
}

/// Creates an [ObservableBool] from a `bool` literal or value.
///
/// Cria um [ObservableBool] a partir de um literal ou valor `bool`.
extension ObservableBoolExtension on bool {
  /// Wraps this value in an [ObservableBool].
  ///
  /// Envolve este valor em um [ObservableBool].
  ObservableBool get obs => ObservableBool(this);
}

/// Creates an [ObservableString] from a `String` literal or value.
///
/// Cria um [ObservableString] a partir de um literal ou valor `String`.
extension ObservableStringExtension on String {
  /// Wraps this value in an [ObservableString].
  ///
  /// Envolve este valor em um [ObservableString].
  ObservableString get obs => ObservableString(this);
}

/// Creates a plain [Observable] from any value that has no dedicated
/// specialization.
///
/// Cria um [Observable] simples a partir de qualquer valor que não tenha
/// uma especialização dedicada.
extension ObservableAnyExtension<T> on T {
  /// Wraps this value in a generic [Observable].
  ///
  /// Envolve este valor em um [Observable] genérico.
  Observable<T> get obs => Observable<T>(this);
}

/// Creates an [ObservableList] from a `List`.
///
/// Cria uma [ObservableList] a partir de uma `List`.
extension ObservableListExtension<E> on List<E> {
  /// Wraps this list in an [ObservableList].
  ///
  /// Envolve esta lista em uma [ObservableList].
  ObservableList<E> get obs => ObservableList<E>(this);
}

/// Creates an [ObservableMap] from a `Map`.
///
/// Cria um [ObservableMap] a partir de um `Map`.
extension ObservableMapExtension<K, V> on Map<K, V> {
  /// Wraps this map in an [ObservableMap].
  ///
  /// Envolve este mapa em um [ObservableMap].
  ObservableMap<K, V> get obs => ObservableMap<K, V>(this);
}

/// Creates an [ObservableSet] from a `Set`.
///
/// Cria um [ObservableSet] a partir de um `Set`.
extension ObservableSetExtension<E> on Set<E> {
  /// Wraps this set in an [ObservableSet].
  ///
  /// Envolve este conjunto em um [ObservableSet].
  ObservableSet<E> get obs => ObservableSet<E>(this);
}
