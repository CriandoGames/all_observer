import 'observable.dart';

/// An [Observable] specialized for `int`, adding numeric operators.
///
/// Um [Observable] especializado para `int`, adicionando operadores
/// numéricos.
///
/// Example / Exemplo:
/// ```dart
/// final count = 0.obs;
/// count++;
/// count += 5;
/// ```
class ObservableInt extends Observable<int> {
  /// Creates an [ObservableInt] holding [initialValue].
  ///
  /// Cria um [ObservableInt] contendo [initialValue].
  ObservableInt(super.initialValue, {super.name});

  /// Returns a new value incremented by [other] without assigning it.
  ///
  /// Retorna um novo valor incrementado por [other], sem atribuí-lo.
  int operator +(int other) => value + other;

  /// Returns a new value decremented by [other] without assigning it.
  ///
  /// Retorna um novo valor decrementado por [other], sem atribuí-lo.
  int operator -(int other) => value - other;
}

/// An [Observable] specialized for `double`, adding numeric operators.
///
/// Um [Observable] especializado para `double`, adicionando operadores
/// numéricos.
class ObservableDouble extends Observable<double> {
  /// Creates an [ObservableDouble] holding [initialValue].
  ///
  /// Cria um [ObservableDouble] contendo [initialValue].
  ObservableDouble(super.initialValue, {super.name});

  /// Returns a new value incremented by [other] without assigning it.
  ///
  /// Retorna um novo valor incrementado por [other], sem atribuí-lo.
  double operator +(double other) => value + other;

  /// Returns a new value decremented by [other] without assigning it.
  ///
  /// Retorna um novo valor decrementado por [other], sem atribuí-lo.
  double operator -(double other) => value - other;
}

/// An [Observable] specialized for `bool`, adding [toggle].
///
/// Um [Observable] especializado para `bool`, adicionando [toggle].
///
/// Example / Exemplo:
/// ```dart
/// final active = false.obs;
/// active.toggle();
/// ```
class ObservableBool extends Observable<bool> {
  /// Creates an [ObservableBool] holding [initialValue].
  ///
  /// Cria um [ObservableBool] contendo [initialValue].
  ObservableBool(super.initialValue, {super.name});

  /// Flips the current value.
  ///
  /// Inverte o valor atual.
  void toggle() => value = !value;
}

/// An [Observable] specialized for `String`.
///
/// Um [Observable] especializado para `String`.
///
/// Example / Exemplo:
/// ```dart
/// final name = 'Carlos'.obs;
/// name.value += '!';
/// ```
class ObservableString extends Observable<String> {
  /// Creates an [ObservableString] holding [initialValue].
  ///
  /// Cria um [ObservableString] contendo [initialValue].
  ObservableString(super.initialValue, {super.name});

  /// Whether the current value is empty.
  ///
  /// Se o valor atual está vazio.
  bool get isEmpty => value.isEmpty;

  /// Whether the current value is not empty.
  ///
  /// Se o valor atual não está vazio.
  bool get isNotEmpty => value.isNotEmpty;
}
