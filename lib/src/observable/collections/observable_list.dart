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

  /// Internal constructor that takes ownership of [list] without copying
  /// it. Only safe for lists the caller just created and doesn't hold a
  /// reference to elsewhere (e.g. the result of `List<E>.generate`) — used
  /// by the `factory` constructors below to avoid allocating twice.
  ///
  /// Construtor interno que assume posse de [list] sem copiá-la. Só é
  /// seguro para listas que o chamador acabou de criar e não guarda
  /// referência em outro lugar (ex.: o resultado de `List<E>.generate`) —
  /// usado pelos construtores `factory` abaixo para evitar alocar duas
  /// vezes.
  ObservableList._owned(this._list, this._name);

  /// Creates an [ObservableList] of the given [length] with every position
  /// set to [fill]. Mirrors `List<E>.filled`.
  ///
  /// Cria uma [ObservableList] com [length] posições, todas com o valor
  /// [fill]. Espelha `List<E>.filled`.
  factory ObservableList.filled(
    int length,
    E fill, {
    bool growable = false,
    String? name,
  }) {
    return ObservableList<E>._owned(
      List<E>.filled(length, fill, growable: growable),
      name,
    );
  }

  /// Creates an empty, growable-by-default [ObservableList]. Mirrors
  /// `List<E>.empty`.
  ///
  /// Cria uma [ObservableList] vazia, crescível por padrão. Espelha
  /// `List<E>.empty`.
  factory ObservableList.empty({bool growable = false, String? name}) {
    return ObservableList<E>._owned(List<E>.empty(growable: growable), name);
  }

  /// Creates an [ObservableList] containing all [elements]. Mirrors
  /// `List<E>.from`, including its runtime type check on every element.
  ///
  /// Cria uma [ObservableList] contendo todos os [elements]. Espelha
  /// `List<E>.from`, incluindo a checagem de tipo em tempo de execução de
  /// cada elemento.
  factory ObservableList.from(
    Iterable<dynamic> elements, {
    bool growable = true,
    String? name,
  }) {
    return ObservableList<E>._owned(
      List<E>.from(elements, growable: growable),
      name,
    );
  }

  /// Creates an [ObservableList] containing all [elements]. Mirrors
  /// `List<E>.of`.
  ///
  /// Cria uma [ObservableList] contendo todos os [elements]. Espelha
  /// `List<E>.of`.
  factory ObservableList.of(
    Iterable<E> elements, {
    bool growable = true,
    String? name,
  }) {
    return ObservableList<E>._owned(
      List<E>.of(elements, growable: growable),
      name,
    );
  }

  /// Creates an [ObservableList] with [length] elements, each produced by
  /// calling [generator] with its index. Mirrors `List<E>.generate`.
  ///
  /// Cria uma [ObservableList] com [length] elementos, cada um produzido
  /// chamando [generator] com seu índice. Espelha `List<E>.generate`.
  factory ObservableList.generate(
    int length,
    E Function(int index) generator, {
    bool growable = true,
    String? name,
  }) {
    return ObservableList<E>._owned(
      List<E>.generate(length, generator, growable: growable),
      name,
    );
  }

  /// Creates an [ObservableList] wrapping an unmodifiable snapshot of
  /// [elements]. Mirrors `List<E>.unmodifiable`: reads work normally, but
  /// every mutating member throws `UnsupportedError`, same as it would on
  /// a plain unmodifiable `List`.
  ///
  /// Cria uma [ObservableList] envolvendo um retrato imutável de
  /// [elements]. Espelha `List<E>.unmodifiable`: leituras funcionam
  /// normalmente, mas todo membro mutante lança `UnsupportedError`, assim
  /// como aconteceria em uma `List` imutável comum.
  factory ObservableList.unmodifiable(Iterable<E> elements, {String? name}) {
    return ObservableList<E>._owned(List<E>.unmodifiable(elements), name);
  }

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
    if (isMutationBlocked) {
      return;
    }
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
    if (isMutationBlocked) {
      return;
    }
    _list[index] = value;
    notifyChanged();
  }

  @override
  void add(E element) {
    if (isMutationBlocked) {
      return;
    }
    _list.add(element);
    notifyChanged();
  }

  @override
  void addAll(Iterable<E> iterable) {
    if (isMutationBlocked) {
      return;
    }
    _list.addAll(iterable);
    notifyChanged();
  }

  @override
  bool remove(Object? element) {
    if (isMutationBlocked) {
      return false;
    }
    final bool removed = _list.remove(element);
    if (removed) {
      notifyChanged();
    }
    return removed;
  }

  @override
  E removeAt(int index) {
    // Blocked: return what *would* have been removed without actually
    // mutating the list, so the closed collection's data stays untouched
    // while the return type's contract (a non-nullable E) is still met.
    //
    // Bloqueado: retorna o que *teria sido* removido sem de fato mutar a
    // lista, para que os dados da coleção fechada permaneçam intocados
    // enquanto o contrato do tipo de retorno (um E não anulável) ainda é
    // respeitado.
    if (isMutationBlocked) {
      return _list[index];
    }
    final E removed = _list.removeAt(index);
    notifyChanged();
    return removed;
  }

  @override
  void clear() {
    if (_list.isEmpty || isMutationBlocked) {
      return;
    }
    _list.clear();
    notifyChanged();
  }

  @override
  void sort([int Function(E a, E b)? compare]) {
    if (isMutationBlocked) {
      return;
    }
    _list.sort(compare);
    notifyChanged();
  }

  /// Shuffles the list order and notifies once, regardless of length.
  ///
  /// Embaralha a ordem da lista e notifica uma única vez, independente do
  /// tamanho.
  @override
  void shuffle([Random? random]) {
    if (isMutationBlocked) {
      return;
    }
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
    if (isMutationBlocked) {
      return;
    }
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
    if (isMutationBlocked) {
      return;
    }
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
    if (isMutationBlocked) {
      return;
    }
    _list.insertAll(index, iterable);
    notifyChanged();
  }

  @override
  void insert(int index, E element) {
    if (isMutationBlocked) {
      return;
    }
    _list.insert(index, element);
    notifyChanged();
  }

  /// Replaces every existing element with a single [element], notifying
  /// listeners exactly once (not once for the implicit clear and once for
  /// the add).
  ///
  /// Substitui todos os elementos existentes por um único [element],
  /// notificando os listeners exatamente uma vez (não uma vez para o
  /// clear implícito e outra para o add).
  void assign(E element) {
    if (isMutationBlocked) {
      return;
    }
    _list
      ..clear()
      ..add(element);
    notifyChanged();
  }

  /// Replaces every existing element with the elements of [iterable],
  /// notifying listeners exactly once.
  ///
  /// Substitui todos os elementos existentes pelos elementos de
  /// [iterable], notificando os listeners exatamente uma vez.
  void assignAll(Iterable<E> iterable) {
    if (isMutationBlocked) {
      return;
    }
    _list
      ..clear()
      ..addAll(iterable);
    notifyChanged();
  }

  /// Adds [element] only when [condition] is `true`. A `false` condition
  /// is a silent no-op — no read, no write, no notification.
  ///
  /// Adiciona [element] apenas quando [condition] é `true`. Uma condition
  /// `false` é um no-op silencioso — sem leitura, sem escrita, sem
  /// notificação.
  void addIf(bool condition, E element) {
    if (condition) {
      add(element);
    }
  }

  /// Adds every element of [iterable] only when [condition] is `true`.
  ///
  /// Adiciona todos os elementos de [iterable] apenas quando [condition]
  /// é `true`.
  void addAllIf(bool condition, Iterable<E> iterable) {
    if (condition) {
      addAll(iterable);
    }
  }

  /// Adds [element] only when it isn't `null`. Handy as a one-liner where
  /// a value may or may not be present, e.g.
  /// `items.addIfNotNull(parseOrNull(input))`.
  ///
  /// Adiciona [element] apenas quando não é `null`. Útil como atalho
  /// quando um valor pode ou não estar presente, ex.:
  /// `items.addIfNotNull(parseOrNull(input))`.
  void addIfNotNull(E? element) {
    if (element != null) {
      add(element);
    }
  }
}
