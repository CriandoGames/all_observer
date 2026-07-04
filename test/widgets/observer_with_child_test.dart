import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/widgets/observer.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  group('Observer.withChild', () {
    testWidgets('does not rebuild the static child when the observed value '
        'changes, but does rebuild the builder-owned part', (tester) async {
      final Observable<int> count = Observable<int>(0);
      int childBuilds = 0;
      int builderCalls = 0;

      final Widget staticChild = Builder(
        builder: (context) {
          childBuilds++;
          return const Text('static');
        },
      );

      await tester.pumpWidget(
        _wrap(
          Observer.withChild(
            builder: (context, child) {
              builderCalls++;
              return Column(children: <Widget>[Text('${count.value}'), child]);
            },
            child: staticChild,
          ),
        ),
      );

      expect(childBuilds, 1);
      expect(builderCalls, 1);
      expect(find.text('0'), findsOneWidget);
      expect(find.text('static'), findsOneWidget);

      count.value = 1;
      await tester.pump();

      expect(find.text('1'), findsOneWidget);
      // The builder itself reran (it needs to, to reflect the new count),
      // but the static child widget instance was never rebuilt again.
      expect(builderCalls, 2);
      expect(childBuilds, 1);
    });

    testWidgets('tracks dependencies read inside builder like a normal '
        'Observer', (tester) async {
      final Observable<int> a = Observable<int>(1);
      await tester.pumpWidget(
        _wrap(
          Observer.withChild(
            builder: (context, child) => Text('${a.value}'),
            child: const SizedBox(),
          ),
        ),
      );
      expect(find.text('1'), findsOneWidget);
      a.value = 2;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);
    });
  });
}
