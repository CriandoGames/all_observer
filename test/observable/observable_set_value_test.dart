import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable.dart';

void main() {
  group('Observable.setValue', () {
    test('setValue assigns null to a nullable Observable and notifies', () {
      final Observable<String?> name = Observable<String?>('a');
      int calls = 0;
      name.addListener(() => calls++);
      name.setValue(null);
      expect(name.value, isNull);
      expect(calls, 1);
    });

    test('setValue behaves like the value setter for non-null values', () {
      final Observable<int> count = Observable<int>(0);
      int calls = 0;
      count.addListener(() => calls++);
      count.setValue(5);
      expect(count.value, 5);
      expect(calls, 1);
      // Assigning the same value again does not notify.
      count.setValue(5);
      expect(calls, 1);
    });

    test('call() cannot assign null (documented ambiguity): passing null '
        'reads the current value instead of assigning', () {
      final Observable<String?> name = Observable<String?>('a');
      final String? result = name(null);
      expect(result, 'a'); // unchanged: call(null) is a read, not a write
      expect(name.value, 'a');
    });
  });
}
