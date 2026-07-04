import 'dart:collection';

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
    _list.clear();
    notifyChanged();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    _list.sort(compare);
    notifyChanged();
  }
}
