import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable_extensions.dart';
import 'package:all_observer/src/observable/observable_types.dart';

void main() {
  group('ObservableInt', () {
    test('.obs creates an ObservableInt', () {
      final ObservableInt count = 0.obs;
      expect(count, isA<ObservableInt>());
      expect(count.value, 0);
    });

    test('operator + and - compute without assigning', () {
      final ObservableInt count = 5.obs;
      expect(count + 2, 7);
      expect(count - 2, 3);
      expect(count.value, 5);
    });

    test('++ and += operators assign the new value', () {
      final ObservableInt count = 0.obs;
      count.value++;
      expect(count.value, 1);
      count.value += 4;
      expect(count.value, 5);
    });
  });

  group('ObservableDouble', () {
    test('.obs creates an ObservableDouble', () {
      final ObservableDouble price = 9.99.obs;
      expect(price, isA<ObservableDouble>());
      expect(price.value, 9.99);
    });

    test('operator + and - compute without assigning', () {
      final ObservableDouble price = 1.5.obs;
      expect(price + 0.5, 2.0);
      expect(price - 0.5, 1.0);
    });
  });

  group('ObservableBool', () {
    test('.obs creates an ObservableBool', () {
      final ObservableBool active = false.obs;
      expect(active, isA<ObservableBool>());
    });

    test('toggle flips the value', () {
      final ObservableBool active = false.obs;
      active.toggle();
      expect(active.value, isTrue);
      active.toggle();
      expect(active.value, isFalse);
    });
  });

  group('ObservableString', () {
    test('.obs creates an ObservableString', () {
      final ObservableString name = 'Carlos'.obs;
      expect(name, isA<ObservableString>());
      expect(name.isNotEmpty, isTrue);
    });

    test('value += appends to the current string', () {
      final ObservableString name = 'Carlos'.obs;
      name.value += '!';
      expect(name.value, 'Carlos!');
    });

    test('isEmpty reflects an empty string', () {
      final ObservableString name = ''.obs;
      expect(name.isEmpty, isTrue);
    });
  });
}
