import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ValueListenable-compatible listener contracts', () {
    test('Observable addListener/removeListener controls notifications', () {
      final Observable<int> source = Observable<int>(0);
      int calls = 0;
      void listener() => calls++;

      source.addListener(listener);
      source.value = 1;
      expect(calls, 1);
      expect(source.hasListeners, isTrue);

      source.removeListener(listener);
      source.value = 2;
      expect(calls, 1);
      expect(source.hasListeners, isFalse);
      source.close();
    });

    test('Computed addListener/removeListener controls notifications', () {
      final Observable<int> source = Observable<int>(1);
      final Computed<int> doubled = Computed<int>(() => source.value * 2);
      int calls = 0;
      void listener() => calls++;

      doubled.addListener(listener);
      expect(doubled.value, 2);
      source.value = 2;
      expect(calls, 1);

      doubled.removeListener(listener);
      source.value = 3;
      expect(calls, 1);
      expect(doubled.value, 6);

      doubled.close();
      source.close();
    });
  });

  group('CoreComputed post-close edge contract', () {
    test('first read after close computes once without subscribing', () {
      final CoreObservable<int> source = CoreObservable<int>(2);
      int computes = 0;
      final CoreComputed<int> computed = CoreComputed<int>(() {
        computes++;
        return source.value * 3;
      });

      computed.close();
      expect(computed.value, 6);
      expect(computes, 1);
      expect(source.hasListeners, isFalse);

      source.value = 4;
      expect(computed.value, 6);
      expect(computes, 1);
      expect(source.hasListeners, isFalse);
      source.close();
    });

    test('close after evaluation freezes the last value', () {
      final CoreObservable<int> source = CoreObservable<int>(2);
      int computes = 0;
      final CoreComputed<int> computed = CoreComputed<int>(() {
        computes++;
        return source.value * 3;
      });
      expect(computed.value, 6);

      computed.close();
      source.value = 4;

      expect(computed.value, 6);
      expect(computes, 1);
      expect(source.hasListeners, isFalse);
      source.close();
    });
  });
}
