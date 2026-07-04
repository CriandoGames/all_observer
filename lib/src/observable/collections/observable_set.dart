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
    _set.clear();
    notifyChanged();
  }

  @override
  Set<E> toSet() => Set<E>.of(_set);
}
