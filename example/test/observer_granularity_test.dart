import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

/// This is the measurable "sales pitch" of the library: rebuild
/// granularity. Two `Observer`s each read a *different* observable;
/// mutating one must rebuild only the `Observer` that actually reads it,
/// leaving the other's build count untouched.
void main() {
  testWidgets(
    'only the Observer that reads the changed observable rebuilds',
    (tester) async {
      final ObservableInt a = 0.obs;
      final ObservableInt b = 0.obs;
      int buildsA = 0;
      int buildsB = 0;
      addTearDown(a.close);
      addTearDown(b.close);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: <Widget>[
                Observer(() {
                  buildsA++;
                  return Text('a:${a.value}');
                }),
                Observer(() {
                  buildsB++;
                  return Text('b:${b.value}');
                }),
              ],
            ),
          ),
        ),
      );

      // Initial build: each Observer builds exactly once.
      expect(buildsA, 1);
      expect(buildsB, 1);

      a.value = 1;
      await tester.pump();

      // Only the Observer reading `a` rebuilt — `b`'s Observer is
      // untouched. This is the granular-rebuild guarantee: dependencies are
      // discovered per-Observer, per-read, not per-widget-subtree.
      expect(buildsA, 2);
      expect(buildsB, 1);
      expect(find.text('a:1'), findsOneWidget);
      expect(find.text('b:0'), findsOneWidget);

      b.value = 5;
      await tester.pump();

      expect(buildsA, 2, reason: 'unrelated write must not rebuild a\'s Observer');
      expect(buildsB, 2);
    },
  );
}
