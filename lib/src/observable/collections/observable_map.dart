import 'dart:collection';

import '_collection_support.dart';

/// A reactive [Map]: every read (`[]`, `keys`, `values`, `length`, ...)
/// registers the active [Observer] as a dependency, and every mutation
/// (`[]=`, `remove`, `clear`, `addAll`, ...) notifies listeners.
///
/// Um [Map] reativo: toda leitura (`[]`, `keys`, `values`, `length`, ...)
/// registra o [Observer] ativo como dependência, e toda mutação (`[]=`,
/// `remove`, `clear`, `addAll`, ...) notifica os listeners.
class ObservableMap<K, V> extends MapBase<K, V> with CollectionSupport {
  /// Creates an [ObservableMap] wrapping a copy of [initial].
  ///
  /// Cria um [ObservableMap] envolvendo uma cópia de [initial].
  ObservableMap([Map<K, V>? initial, String? name])
      : _map = Map<K, V>.of(initial ?? <K, V>{}),
        _name = name;

  final Map<K, V> _map;
  final String? _name;

  @override
  String get debugLabel => 'ObservableMap(${_name ?? '#$hashCode'})';

  @override
  V? operator [](Object? key) {
    reportRead();
    return _map[key];
  }

  @override
  void operator []=(K key, V value) {
    _map[key] = value;
    notifyChanged();
  }

  @override
  V? remove(Object? key) {
    final bool hadKey = _map.containsKey(key);
    final V? removed = _map.remove(key);
    if (hadKey) {
      notifyChanged();
    }
    return removed;
  }

  @override
  void clear() {
    _map.clear();
    notifyChanged();
  }

  @override
  void addAll(Map<K, V> other) {
    _map.addAll(other);
    notifyChanged();
  }

  @override
  Iterable<K> get keys {
    reportRead();
    return _map.keys;
  }

  @override
  int get length {
    reportRead();
    return _map.length;
  }

  @override
  bool containsKey(Object? key) {
    reportRead();
    return _map.containsKey(key);
  }
}
