import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Observable primitive aliases', () {
    test('construct the corresponding Observable types from public barrel', () {
      final ObsBool loading = ObsBool(false);
      final ObsInt count = ObsInt(0);
      final ObsDouble price = ObsDouble(1.5);
      final ObsString name = ObsString('all_observer');

      expect(loading, isA<Observable<bool>>());
      expect(count, isA<Observable<int>>());
      expect(price, isA<Observable<double>>());
      expect(name, isA<Observable<String>>());
    });

    test('forward name and equals to the Observable constructor', () {
      final ObsInt count = ObsInt(
        10,
        name: 'count',
        equals: (int a, int b) => a.isEven == b.isEven,
      );
      int notifications = 0;
      count.listen((int _) => notifications++);

      count.value = 12;
      expect(notifications, 0, reason: 'custom equals treats both as equal');

      count.value = 13;
      expect(notifications, 1);
      count.close();
    });

    test(
      'read, write, listen, refresh and close keep Observable semantics',
      () {
        final ObsBool loading = ObsBool(false, name: 'loading');
        final List<bool> values = <bool>[];
        final ObservableSubscription subscription = loading.listen(values.add);

        expect(loading.value, isFalse);
        loading.value = true;
        loading.refresh();

        expect(values, <bool>[true, true]);
        expect(subscription.isActive, isTrue);

        loading.close();
        expect(loading.isClosed, isTrue);
        expect(loading.hasListeners, isFalse);
        expect(() => loading.value = false, returnsNormally);
        expect(loading.value, isTrue);
        expect(values, <bool>[true, true]);
      },
    );
  });
}
