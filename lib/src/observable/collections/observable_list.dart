import 'dart:collection';
import 'dart:math' show Random;

import '_collection_support.dart';

/// A reactive [List]: every read (length, `[]`, iteration) registers the
/// active [Observer] as a dependency, and every mutation (`add`, `remove`,
/// `[]=`, `clear`, `addAll`, ...) notifies listeners.
///
/// Uma [List] reativa: toda leitura (length, `[]`, iteração) registra o
/// [Observer] ativo como dependência, e toda mutação (`add`, `remove`,
/// `[]=`, `clear`, `addAll`, ...) notifica os listeners.
///
/// Example / Exemplo:
/// ```dart
/// final items = <String>[].obs;
/// Observer(() => Text('${items.length} items'));
/// items.add('one');
/// ```
class ObservableList<E> extends ListBase<E> with CollectionSupport {
  /// Creates an [ObservableList] wrapping a copy of [initial].
  ///
  /// Cria uma [ObservableList] envolvendo uma cópia de [initial].
  ObservableList([List<E>? initial, String? name])
      : _list = List<E>.of(initial ?? <E>[]),
        _name = name;

  final List<E> _list;
  final String? _name;

  @override
  String get debugLabel => 'ObservableList(${_name ?? '#$hashCode'})';

  @override
  int get length {
    reportRead();
    return _list.length;
  }

  @override
  set length(int newLength) {
    _list.length = newLength;
    notifyChanged();
  }

  @override
  E operator [](int index) {
    reportRead();
    return _list[index];
  }

  @override
  void operator []=(int index, E value) {
    _list[index] = value;
    notifyChanged();
  }

  @override
  void add(E element) {
    _list.add(element);
    notifyChanged();
  }

  @override
  void addAll(Iterable<E> iterable) {
    _list.addAll(iterable);
    notifyChanged();
  }

  @override
  bool remove(Object? element) {
    final bool removed = _list.remove(element);
    if (removed) {
      notifyChanged();
    }
    return removed;
  }

  @override
  E removeAt(int index) {
    final E removed = _list.removeAt(index);
    notifyChanged();
    return removed;
  }

  @override
  void clear() {
    if (_list.isEmpty) {
      return;
    }
    _list.clear();
    notifyChanged();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _list.sort(compare);
    notifyChanged();
  }

  /// Shuffles the list order and notifies once, regardless of length.
  ///
  /// Embaralha a ordem da lista e notifica uma única vez, independente do
  /// tamanho.
  @override
  void shuffle([Random? random]) {
    _list.shuffle(random);
    notifyChanged();
  }

  /// Removes every element that satisfies [test], notifying at most once
  /// (never once per removed element, and not at all if nothing matched).
  /// This overrides `ListBase`'s default implementation, which removes one
  /// element at a time and would otherwise notify per element.
  ///
  /// Remove todo elemento que satisfaça [test], notificando no máximo uma
  /// vez (nunca uma vez por elemento removido, e nenhuma vez se nada
  /// combinou). Sobrescreve a implementação padrão de `ListBase`, que
  /// remove um elemento por vez e, de outra forma, notificaria por
  /// elemento.
  @override
  void removeWhere(bool Function(E element) test) {
    final int before = _list.length;
    _list.removeWhere(test);
    if (_list.length != before) {
      notifyChanged();
    }
  }

  /// Keeps only the elements that satisfy [test], notifying at most once.
  ///
  /// Mantém apenas os elementos que satisfazem [test], notificando no
  /// máximo uma vez.
  @override
  void retainWhere(bool Function(E element) test) {
    final int before = _list.length;
    _list.retainWhere(test);
    if (_list.length != before) {
      notifyChanged();
    }
  }

  /// Inserts every element of [iterable] at [index], notifying once
  /// regardless of how many elements were inserted.
  ///
  /// Insere cada elemento de [iterable] em [index], notificando uma única
  /// vez independente de quantos elementos foram inseridos.
  @override
  void insertAll(int index, Iterable<E> iterable) {
    _list.insertAll(index, iterable);
    notifyChanged();
  }

  @override
  void insert(int index, E element) {
    _list.insert(index, element);
    notifyChanged();
  }
}
