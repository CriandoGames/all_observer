import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(ObserverConfig.reset);

  group('Audit P0 - computed failure recovery', () {
    test(
      'A01 retries after an initial compute error and keeps invalidating',
      () {
        // Setup: the first compute reads a dependency and throws.
        final source = Observable<int>(1, name: 'auditSource');
        var evaluations = 0;
        final computed = Computed<int>(() {
          evaluations++;
          final value = source.value;
          if (evaluations == 1) {
            throw StateError('initial failure');
          }
          return value + 40;
        }, name: 'auditComputed');

        addTearDown(computed.close);
        addTearDown(source.close);

        // Action + expectation: the original error is observable.
        expect(() => computed.value, throwsA(isA<StateError>()));
        expect(evaluations, 1);

        // A failed first evaluation must not poison the computed.
        expect(computed.value, 41);
        expect(evaluations, 2);

        source.value = 2;

        // Later dependency changes must still invalidate and recompute.
        expect(computed.value, 42);
        expect(evaluations, greaterThanOrEqualTo(3));
      },
    );
  });
}
