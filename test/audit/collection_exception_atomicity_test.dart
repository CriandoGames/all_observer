import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ThrowingIterable<T> extends Iterable<T> {
  _ThrowingIterable(this._valuesBeforeThrow, {required this.error});

  final List<T> _valuesBeforeThrow;
  final StateError error;
  var moveNextCalls = 0;

  @override
  Iterator<T> get iterator => _ThrowingIterator<T>(this);
}

final class _ThrowingIterator<T> implements Iterator<T> {
  _ThrowingIterator(this._owner);

  final _ThrowingIterable<T> _owner;
  var _index = -1;
  T? _current;

  @override
  T get current => _current as T;

  @override
  bool moveNext() {
    _owner.moveNextCalls++;
    _index++;
    if (_index >= _owner._valuesBeforeThrow.length) {
      throw _owner.error;
    }
    _current = _owner._valuesBeforeThrow[_index];
    return true;
  }
}

String _listSummary(Iterable<int> values) => values.join(',');

String _setSummary(Set<int> values) {
  final sorted = values.toList()..sort();
  return sorted.join(',');
}

String _mapSummary(Map<int, String> values) {
  return values.entries.map((entry) => '${entry.key}:${entry.value}').join(',');
}

void main() {
  tearDown(ObserverConfig.reset);

  group('Audit 2 - collection exception atomicity', () {
    test('ObservableList.removeWhere is atomic when predicate throws', () {
      final items = ObservableList<int>(<int>[
        1,
        2,
        3,
        4,
        5,
      ], 'auditListRemoveWhere');
      final derived = Computed<String>(() => _listSummary(items));
      addTearDown(() {
        derived.close();
        items.close();
      });

      final before = items.toList();
      final beforeDerived = derived.value;
      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      Object? error;
      try {
        items.removeWhere((value) {
          calls++;
          if (value == 4) {
            throw StateError('predicate failed at 4');
          }
          return value.isOdd;
        });
      } catch (caught) {
        error = caught;
      }

      final afterException = items.toList();
      final derivedAfterException = derived.value;
      final notificationsAfterException = notifications;

      items.add(99);
      final afterRecovery = items.toList();
      final derivedAfterRecovery = derived.value;

      expect(error, isA<StateError>());
      expect(calls, 4);
      expect(afterException, before);
      expect(notificationsAfterException, 0);
      expect(derivedAfterException, beforeDerived);
      expect(notifications, notificationsAfterException + 1);
      expect(derivedAfterRecovery, _listSummary(afterRecovery));
    });

    test('ObservableList.retainWhere is atomic when predicate throws', () {
      final items = ObservableList<int>(<int>[
        1,
        2,
        3,
        4,
        5,
      ], 'auditListRetainWhere');
      final derived = Computed<String>(() => _listSummary(items));
      addTearDown(() {
        derived.close();
        items.close();
      });

      final before = items.toList();
      final beforeDerived = derived.value;
      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      Object? error;
      try {
        items.retainWhere((value) {
          calls++;
          if (value == 4) {
            throw StateError('predicate failed at 4');
          }
          return value.isEven;
        });
      } catch (caught) {
        error = caught;
      }

      final afterException = items.toList();
      final derivedAfterException = derived.value;
      final notificationsAfterException = notifications;

      items.add(99);
      final afterRecovery = items.toList();
      final derivedAfterRecovery = derived.value;

      expect(error, isA<StateError>());
      expect(calls, 4);
      expect(afterException, before);
      expect(notificationsAfterException, 0);
      expect(derivedAfterException, beforeDerived);
      expect(notifications, notificationsAfterException + 1);
      expect(derivedAfterRecovery, _listSummary(afterRecovery));
    });

    test('ObservableSet.addAll is atomic when iterable throws', () {
      final items = ObservableSet<int>(<int>{10}, 'auditSetAddAll');
      final derived = Computed<String>(() => _setSummary(items));
      addTearDown(() {
        derived.close();
        items.close();
      });

      final before = items.toSet();
      final beforeDerived = derived.value;
      final iterable = _ThrowingIterable<int>(<int>[
        1,
        2,
      ], error: StateError('iterable failed'));
      var notifications = 0;
      items.listen(() => notifications++);

      Object? error;
      try {
        items.addAll(iterable);
      } catch (caught) {
        error = caught;
      }

      final afterException = items.toSet();
      final derivedAfterException = derived.value;
      final notificationsAfterException = notifications;

      items.add(99);
      final afterRecovery = items.toSet();
      final derivedAfterRecovery = derived.value;

      expect(error, isA<StateError>());
      expect(iterable.moveNextCalls, 3);
      expect(afterException, before);
      expect(notificationsAfterException, 0);
      expect(derivedAfterException, beforeDerived);
      expect(notifications, notificationsAfterException + 1);
      expect(derivedAfterRecovery, _setSummary(afterRecovery));
    });

    test('ObservableSet.removeWhere is atomic when predicate throws', () {
      final items = ObservableSet<int>(<int>{
        1,
        2,
        3,
        4,
        5,
      }, 'auditSetRemoveWhere');
      final derived = Computed<String>(() => _setSummary(items));
      addTearDown(() {
        derived.close();
        items.close();
      });

      final before = items.toSet();
      final beforeDerived = derived.value;
      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      Object? error;
      try {
        items.removeWhere((value) {
          calls++;
          if (value == 4) {
            throw StateError('predicate failed at 4');
          }
          return value.isOdd;
        });
      } catch (caught) {
        error = caught;
      }

      final afterException = items.toSet();
      final derivedAfterException = derived.value;
      final notificationsAfterException = notifications;

      items.add(99);
      final afterRecovery = items.toSet();
      final derivedAfterRecovery = derived.value;

      expect(error, isA<StateError>());
      expect(calls, 4);
      expect(afterException, before);
      expect(notificationsAfterException, 0);
      expect(derivedAfterException, beforeDerived);
      expect(notifications, notificationsAfterException + 1);
      expect(derivedAfterRecovery, _setSummary(afterRecovery));
    });

    test('ObservableSet.retainWhere is atomic when predicate throws', () {
      final items = ObservableSet<int>(<int>{
        1,
        2,
        3,
        4,
        5,
      }, 'auditSetRetainWhere');
      final derived = Computed<String>(() => _setSummary(items));
      addTearDown(() {
        derived.close();
        items.close();
      });

      final before = items.toSet();
      final beforeDerived = derived.value;
      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      Object? error;
      try {
        items.retainWhere((value) {
          calls++;
          if (value == 4) {
            throw StateError('predicate failed at 4');
          }
          return value.isEven;
        });
      } catch (caught) {
        error = caught;
      }

      final afterException = items.toSet();
      final derivedAfterException = derived.value;
      final notificationsAfterException = notifications;

      items.add(99);
      final afterRecovery = items.toSet();
      final derivedAfterRecovery = derived.value;

      expect(error, isA<StateError>());
      expect(calls, 4);
      expect(afterException, before);
      expect(notificationsAfterException, 0);
      expect(derivedAfterException, beforeDerived);
      expect(notifications, notificationsAfterException + 1);
      expect(derivedAfterRecovery, _setSummary(afterRecovery));
    });

    test('ObservableMap.removeWhere is atomic when predicate throws', () {
      final items = ObservableMap<int, String>(<int, String>{
        1: 'a',
        2: 'b',
        3: 'c',
        4: 'd',
      }, 'auditMapRemoveWhere');
      final derived = Computed<String>(() => _mapSummary(items));
      addTearDown(() {
        derived.close();
        items.close();
      });

      final before = Map<int, String>.of(items);
      final beforeDerived = derived.value;
      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      Object? error;
      try {
        items.removeWhere((key, value) {
          calls++;
          if (key == 3) {
            throw StateError('predicate failed at 3');
          }
          return key.isOdd;
        });
      } catch (caught) {
        error = caught;
      }

      final afterException = Map<int, String>.of(items);
      final derivedAfterException = derived.value;
      final notificationsAfterException = notifications;

      items[99] = 'z';
      final afterRecovery = Map<int, String>.of(items);
      final derivedAfterRecovery = derived.value;

      expect(error, isA<StateError>());
      expect(calls, 3);
      expect(afterException, before);
      expect(notificationsAfterException, 0);
      expect(derivedAfterException, beforeDerived);
      expect(notifications, notificationsAfterException + 1);
      expect(derivedAfterRecovery, _mapSummary(afterRecovery));
    });
  });
}
