import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/logging/observer_config.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/widgets/observer.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('Observer basic reactivity', () {
    testWidgets('rebuilds when a read observable changes', (tester) async {
      final Observable<int> count = Observable<int>(0);
      await tester.pumpWidget(
        _wrap(Observer(() => Text('${count.value}'))),
      );
      expect(find.text('0'), findsOneWidget);
      count.value = 1;
      await tester.pump();
      expect(find.text('1'), findsOneWidget);
    });

    testWidgets('does not rebuild when the assigned value is unchanged '
        'on first assignment', (tester) async {
      final Observable<int> count = Observable<int>(0);
      int builds = 0;
      await tester.pumpWidget(
        _wrap(
          Observer(() {
            builds++;
            return Text('${count.value}');
          }),
        ),
      );
      expect(builds, 1);
      count.value = 0;
      await tester.pump();
      expect(builds, 1);
    });

    testWidgets('supports dynamic dependencies (conditional reads)', (
      tester,
    ) async {
      final Observable<bool> useA = Observable<bool>(true);
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(2);
      await tester.pumpWidget(
        _wrap(
          Observer(() => Text(useA.value ? '${a.value}' : '${b.value}')),
        ),
      );
      expect(find.text('1'), findsOneWidget);

      // Switch dependency from `a` to `b`.
      useA.value = false;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // Now changing `a` should no longer trigger a rebuild.
      a.value = 99;
      await tester.pump();
      expect(find.text('2'), findsOneWidget);

      // But changing `b` should.
      b.value = 42;
      await tester.pump();
      expect(find.text('42'), findsOneWidget);
    });

    testWidgets('unmount clears listeners so further changes are no-ops', (
      tester,
    ) async {
      final Observable<int> count = Observable<int>(0);
      await tester.pumpWidget(
        _wrap(Observer(() => Text('${count.value}'))),
      );
      await tester.pumpWidget(_wrap(const SizedBox()));
      expect(count.hasListeners, isFalse);
      // Should not throw even though nothing is listening anymore.
      count.value = 5;
      await tester.pump();
    });
  });

  group('Observer regression cases', () {
    testWidgets('does not crash when the observable changes right before '
        'the widget is unmounted', (tester) async {
      final Observable<int> count = Observable<int>(0);
      await tester.pumpWidget(
        _wrap(Observer(() => Text('${count.value}'))),
      );
      count.value = 1;
      await tester.pumpWidget(_wrap(const SizedBox()));
      await tester.pump();
      // No exception thrown means the guarded rebuild callback worked.
    });

    testWidgets('nested Observers each track their own dependency via the '
        'tracking stack', (tester) async {
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(2);
      await tester.pumpWidget(
        _wrap(
          Observer(() {
            final String innerText = '';
            return Column(
              children: <Widget>[
                Observer(() => Text('a:${a.value}')),
                Text('b:${b.value}$innerText'),
              ],
            );
          }),
        ),
      );
      expect(find.text('a:1'), findsOneWidget);
      expect(find.text('b:2'), findsOneWidget);

      a.value = 10;
      await tester.pump();
      expect(find.text('a:10'), findsOneWidget);
      expect(find.text('b:2'), findsOneWidget);

      b.value = 20;
      await tester.pump();
      expect(find.text('a:10'), findsOneWidget);
      expect(find.text('b:20'), findsOneWidget);
    });

    testWidgets('assigning the same value on first assignment produces '
        'zero rebuilds', (tester) async {
      final Observable<String> name = Observable<String>('x');
      int builds = 0;
      await tester.pumpWidget(
        _wrap(
          Observer(() {
            builds++;
            return Text(name.value);
          }),
        ),
      );
      expect(builds, 1);
      name.value = 'x';
      await tester.pump();
      expect(builds, 1);
    });

    test('an exception thrown inside a builder still restores the '
        'tracking stack', () {
      final TrackingContext outer = TrackingContext(() {});
      expect(
        () => DependencyTracker.track(outer, () {
          return DependencyTracker.track(
            TrackingContext(() {}),
            () => throw StateError('boom'),
          );
        }),
        throwsStateError,
      );
      expect(DependencyTracker.current, isNull);
    });
  });

  group('Observer misuse warnings', () {
    testWidgets('an Observer that reads nothing warns instead of '
        'throwing by default', (tester) async {
      await tester.pumpWidget(_wrap(Observer(() => const Text('static'))));
      expect(find.text('static'), findsOneWidget);
    });

    testWidgets('strictMode throws when the builder reads nothing', (
      tester,
    ) async {
      ObserverConfig.strictMode = true;
      await tester.pumpWidget(_wrap(Observer(() => const Text('static'))));
      expect(tester.takeException(), isNotNull);
    });
  });
}
