import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/observable_store.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/observable/observable_store_extensions.dart';

/// A tiny in-memory [ObservableStore], standing in for a real backend (e.g.
/// `all_box`) for test purposes only.
class _InMemoryStore<T> implements ObservableStore<T> {
  T? _stored;
  int writeCalls = 0;
  int deleteCalls = 0;

  @override
  T? read() => _stored;

  @override
  void write(T value) {
    writeCalls++;
    _stored = value;
  }

  @override
  void delete() {
    deleteCalls++;
    _stored = null;
  }
}

void main() {
  group('ObservableStore + persistWith', () {
    test('restores the value from the store on binding', () {
      final _InMemoryStore<String> store = _InMemoryStore<String>()
        ..write('restored');
      store.writeCalls = 0; // reset — the write above wasn't via binding.

      final Observable<String> theme = Observable<String>('light');
      theme.persistWith(store);

      expect(theme.value, 'restored');
    });

    test('leaves the value untouched when the store is empty', () {
      final _InMemoryStore<String> store = _InMemoryStore<String>();
      final Observable<String> theme = Observable<String>('light');
      theme.persistWith(store);

      expect(theme.value, 'light');
    });

    test('writes every subsequent value change to the store', () {
      final _InMemoryStore<int> store = _InMemoryStore<int>();
      final Observable<int> counter = Observable<int>(0);
      counter.persistWith(store);

      counter.value = 1;
      counter.value = 2;

      expect(store.read(), 2);
      expect(store.writeCalls, 2);
    });

    test('the returned disposer stops persistence without closing the '
        'Observable', () {
      final _InMemoryStore<int> store = _InMemoryStore<int>();
      final Observable<int> counter = Observable<int>(0);
      final void Function() stop = counter.persistWith(store);

      counter.value = 1;
      expect(store.read(), 1);

      stop();
      counter.value = 2;
      expect(store.read(), 1, reason: 'no longer persisting after stop()');
      expect(counter.isClosed, isFalse);
      expect(counter.value, 2);
    });
  });
}
