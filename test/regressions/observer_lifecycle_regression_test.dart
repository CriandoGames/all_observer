import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

class _UnmountDuringBuildHarness extends StatefulWidget {
  const _UnmountDuringBuildHarness({
    required this.source,
    required this.observerBuilds,
    super.key,
  });

  final Observable<int> source;
  final void Function() observerBuilds;

  @override
  State<_UnmountDuringBuildHarness> createState() =>
      _UnmountDuringBuildHarnessState();
}

class _UnmountDuringBuildHarnessState
    extends State<_UnmountDuringBuildHarness> {
  bool removeObserver = false;

  void removeDuringNextBuild() {
    setState(() => removeObserver = true);
  }

  @override
  Widget build(BuildContext context) {
    if (removeObserver) {
      // The Observer is still subscribed at this point. Because this write
      // happens during build, its rebuild is deferred to post-frame. The
      // Observer is then omitted and disposed by this same build.
      widget.source.value++;
      return const SizedBox();
    }
    return Observer(() {
      widget.observerBuilds();
      return Text('${widget.source.value}');
    });
  }
}

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('Observer lifecycle regressions', () {
    testWidgets('parent rebuilds do not accumulate Observer subscriptions', (
      tester,
    ) async {
      final Observable<int> count = Observable<int>(0);
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.listenerLeakThreshold = 2;
      ObserverConfig.inspectors.add(recorder);
      int parentTick = 0;
      int observerBuilds = 0;

      Widget tree() => _app(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Column(
            children: <Widget>[
              Text('parent:${parentTick++}'),
              Observer(() {
                observerBuilds++;
                return Text('count:${count.value}');
              }),
            ],
          ),
        ),
      );

      await tester.pumpWidget(tree());
      for (int i = 0; i < 100; i++) {
        await tester.pumpWidget(tree());
      }

      expect(count.hasListeners, isTrue);
      expect(
        recorder.events.whereType<WarningEvent>().where(
          (WarningEvent event) => event.label.contains('Possível vazamento'),
        ),
        isEmpty,
        reason: 'retracking must replace, rather than append, subscriptions',
      );

      final int beforeWrites = observerBuilds;
      for (int i = 1; i <= 20; i++) {
        count.value = i;
        await tester.pump();
      }
      expect(observerBuilds - beforeWrites, 20);
      count.close();
    });

    testWidgets('unmount removes subscriptions and later writes are inert', (
      tester,
    ) async {
      final Observable<int> count = Observable<int>(0);
      int builds = 0;
      await tester.pumpWidget(
        _app(
          Observer(() {
            builds++;
            return Text('${count.value}');
          }),
        ),
      );
      expect(count.hasListeners, isTrue);

      await tester.pumpWidget(_app(const SizedBox()));
      expect(count.hasListeners, isFalse);
      final int buildsAfterUnmount = builds;

      expect(() => count.value = 1, returnsNormally);
      await tester.pump();
      expect(builds, buildsAfterUnmount);
      expect(tester.takeException(), isNull);
      count.close();
    });

    testWidgets('removed list items never rebuild after later updates', (
      tester,
    ) async {
      final List<Observable<int>> values = List<Observable<int>>.generate(
        4,
        (int index) => Observable<int>(index),
      );
      final List<int> builds = List<int>.filled(values.length, 0);
      List<int> visible = <int>[0, 1, 2, 3];

      Widget tree() => _app(
        ListView(
          children: visible.map((int index) {
            return Observer(key: ValueKey<int>(index), () {
              builds[index]++;
              return Text('item-$index:${values[index].value}');
            });
          }).toList(),
        ),
      );

      await tester.pumpWidget(tree());
      visible = <int>[0, 2];
      await tester.pumpWidget(tree());
      expect(values[1].hasListeners, isFalse);
      expect(values[3].hasListeners, isFalse);
      final List<int> before = List<int>.of(builds);

      for (final Observable<int> value in values) {
        value.value += 10;
      }
      await tester.pump();

      expect(builds[0], before[0] + 1);
      expect(builds[2], before[2] + 1);
      expect(builds[1], before[1]);
      expect(builds[3], before[3]);
      expect(tester.takeException(), isNull);
      for (final Observable<int> value in values) {
        value.close();
      }
    });

    testWidgets(
      'deferred rebuild does not target an Observer unmounted in same frame',
      (tester) async {
        final Observable<int> count = Observable<int>(0);
        final GlobalKey<_UnmountDuringBuildHarnessState> key =
            GlobalKey<_UnmountDuringBuildHarnessState>();
        int builds = 0;
        await tester.pumpWidget(
          _app(
            _UnmountDuringBuildHarness(
              key: key,
              source: count,
              observerBuilds: () => builds++,
            ),
          ),
        );
        expect(builds, 1);

        key.currentState!.removeDuringNextBuild();
        await tester.pump();
        await tester.pump();

        expect(builds, 1);
        expect(count.hasListeners, isFalse);
        expect(tester.takeException(), isNull);
        count.close();
      },
    );

    testWidgets('ten thousand writes coalesce without listener growth', (
      tester,
    ) async {
      final Observable<int> count = Observable<int>(0);
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.listenerLeakThreshold = 2;
      ObserverConfig.inspectors.add(recorder);
      int builds = 0;
      await tester.pumpWidget(
        _app(
          Observer(() {
            builds++;
            return Text('${count.value}');
          }),
        ),
      );

      for (int i = 1; i <= 10000; i++) {
        count.value = i;
      }
      await tester.pump();

      expect(find.text('10000'), findsOneWidget);
      expect(builds, 2, reason: 'setState calls before a frame are coalesced');
      expect(count.hasListeners, isTrue);
      expect(
        recorder.events.whereType<WarningEvent>().where(
          (WarningEvent event) => event.label.contains('Possível vazamento'),
        ),
        isEmpty,
      );
      count.close();
    });
  });
}
