import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

/// Demonstrates `ObserverConfig.strictMode` catching common misuse as a
/// thrown `ObserverError` instead of a console warning that a CI run could
/// silently miss. Turn it on in `setUp` and always call
/// `ObserverConfig.reset()` in `tearDown` so it doesn't leak into other
/// tests in the same suite.
void main() {
  setUp(() {
    ObserverConfig.strictMode = true;
  });

  tearDown(ObserverConfig.reset);

  testWidgets(
    'an Observer that reads no observable throws instead of only warning',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            // This builder never reads `.value` on anything — a classic
            // copy-paste mistake ("I forgot to read the observable").
            body: Observer(_emptyBuilder),
          ),
        ),
      );

      expect(tester.takeException(), isA<ObserverError>());
    },
  );

  testWidgets(
    'writing to an observable during an Observer build throws instead of '
    'only warning',
    (tester) async {
      final ObservableInt count = 0.obs;
      addTearDown(count.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Observer(() {
              // Mutating `count` while it (or anything else) is being read
              // during a build causes a rebuild loop — a mistake strictMode
              // turns into a hard failure instead of a console warning.
              count.value++;
              return Text('${count.value}');
            }),
          ),
        ),
      );

      expect(tester.takeException(), isA<ObserverError>());
    },
  );
}

Widget _emptyBuilder() => const Text('no observable read here');
