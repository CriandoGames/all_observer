import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _ThrowingIterable extends Iterable<int> {
  const _ThrowingIterable();

  @override
  Iterator<int> get iterator => _ThrowingIterator();
}

final class _ThrowingIterator implements Iterator<int> {
  int _index = -1;

  @override
  int get current => _index;

  @override
  bool moveNext() {
    _index++;
    if (_index == 3) {
      throw StateError('iterable failed');
    }
    return _index < 5;
  }
}

void main() {
  tearDown(ObserverConfig.reset);

  group('Audit P0 - collection atomicity on exceptions', () {
    test('F01 addAll iterable failure leaves the list untouched', () {
      final items = ObservableList<int>(<int>[10], 'auditAddAll');
      addTearDown(items.close);

      var notifications = 0;
      items.listen(() => notifications++);

      expect(
        () => items.addAll(const _ThrowingIterable()),
        throwsA(isA<StateError>()),
      );

      expect(items.toList(), <int>[10]);
      expect(notifications, 0);
    });

    test('F02 removeWhere predicate failure leaves the list untouched', () {
      final items = ObservableList<int>(<int>[1, 2, 3, 4], 'auditRemoveWhere');
      addTearDown(items.close);

      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      expect(
        () => items.removeWhere((value) {
          calls++;
          if (value == 3) {
            throw StateError('predicate failed');
          }
          return value.isOdd;
        }),
        throwsA(isA<StateError>()),
      );

      expect(calls, 3);
      expect(items.toList(), <int>[1, 2, 3, 4]);
      expect(notifications, 0);
    });

    test('F03 sort comparator failure leaves the list untouched', () {
      final items = ObservableList<int>(<int>[5, 4, 3, 2, 1], 'auditSort');
      addTearDown(items.close);

      var calls = 0;
      var notifications = 0;
      items.listen(() => notifications++);

      expect(
        () => items.sort((a, b) {
          calls++;
          if (calls == 3) {
            throw StateError('comparator failed');
          }
          return a.compareTo(b);
        }),
        throwsA(isA<StateError>()),
      );

      expect(calls, 3);
      expect(items.toList(), <int>[5, 4, 3, 2, 1]);
      expect(notifications, 0);
    });
  });
}
