import 'dart:collection';

import '_collection_support.dart';

/// A reactive [Set]: every read (`contains`, `length`, iteration, ...)
/// registers the active [Observer] as a dependency, and every mutation
/// (`add`, `remove`, `clear`, `addAll`, ...) notifies listeners.
///
/// Um [Set] reativo: toda leitura (`contains`, `length`, iteração, ...)
/// registra o [Observer] ativo como dependência, e toda mutação (`add`,
/// `remove`, `clear`, `addAll`, ...) notifica os listeners.
class ObservableSet<E> extends SetBase<E> with CollectionSupport {
  /// Creates an [ObservableSet] wrapping a copy of [initial].
  ///
  /// Cria um [ObservableSet] envolvendo uma cópia de [initial].
  ObservableSet([Set<E>? initial, String? name])
      : _set = Set<E>.of(initial ?? <E>{}),
        _name = name;

  final Set<E> _set;
  final String? _name;

  @override
  String get debugLabel => 'ObservableSet(${_name ?? '#$hashCode'})';

  @override
  bool add(E value) {
    final bool added = _set.add(value);
    if (added) {
      notifyChanged();
    }
    return added;
  }

  @override
  bool contains(Object? element) {
    reportRead();
    return _set.contains(element);
  }

  @override
  Iterator<E> get iterator {
    reportRead();
    return _set.iterator;
  }

  @override
  int get length {
    reportRead();
    return _set.length;
  }

  @override
  E? lookup(Object? element) {
    reportRead();
    return _set.lookup(element);
  }

  @override
  bool remove(Object? value) {
    final bool removed = _set.remove(value);
    if (removed) {
      notifyChanged();
    }
    return removed;
  }

  @override
  void clear() {
    if (_set.isEmpty) {
      return;
    }
    _set.clear();
    notifyChanged();
  }

  /// Adds every element of [elements], notifying at most once regardless
  /// of how many were actually new. This overrides `SetBase`'s default
  /// implementation, which adds one element at a time and would otherwise
  /// notify per newly-added element.
  ///
  /// Adiciona cada elemento de [elements], notificando no máximo uma vez
  /// independente de quantos eram realmente novos. Sobrescreve a
  /// implementação padrão de `SetBase`, que adiciona um elemento por vez e,
  /// de outra forma, notificaria por elemento recém-adicionado.
  @override
  void addAll(Iterable<E> elements) {
    final int before = _set.length;
    _set.addAll(elements);
    if (_set.length != before) {
      notifyChanged();
    }
  }

  /// Removes every element that satisfies [test], notifying at most once.
  ///
  /// Remove todo elemento que satisfaça [test], notificando no máximo uma
  /// vez.
  @override
  void removeWhere(bool Function(E element) test) {
    final int before = _set.length;
    _set.removeWhere(test);
    if (_set.length != before) {
      notifyChanged();
    }
  }

  /// Keeps only the elements that satisfy [test], notifying at most once.
  ///
  /// Mantém apenas os elementos que satisfazem [test], notificando no
  /// máximo uma vez.
  @override
  void retainWhere(bool Function(E element) test) {
    final int before = _set.length;
    _set.retainWhere(test);
    if (_set.length != before) {
      notifyChanged();
    }
  }

  @override
  Set<E> toSet() => Set<E>.of(_set);
}
