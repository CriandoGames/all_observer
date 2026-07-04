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
    if (_map.containsKey(key) && _map[key] == value) {
      return;
    }
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
    if (_map.isEmpty) {
      return;
    }
    _map.clear();
    notifyChanged();
  }

  @override
  void addAll(Map<K, V> other) {
    if (other.isEmpty) {
      return;
    }
    _map.addAll(other);
    notifyChanged();
  }

  /// Removes every entry whose key/value satisfy [test], notifying at most
  /// once regardless of how many entries were removed. This overrides
  /// `MapBase`'s default implementation, which removes one entry at a time
  /// and would otherwise notify per entry.
  ///
  /// Remove toda entrada cuja chave/valor satisfaçam [test], notificando no
  /// máximo uma vez independente de quantas entradas foram removidas.
  /// Sobrescreve a implementação padrão de `MapBase`, que remove uma
  /// entrada por vez e, de outra forma, notificaria por entrada.
  @override
  void removeWhere(bool Function(K key, V value) test) {
    final int before = _map.length;
    _map.removeWhere(test);
    if (_map.length != before) {
      notifyChanged();
    }
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
