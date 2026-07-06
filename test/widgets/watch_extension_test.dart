import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

/// A minimal widget whose `build` is supplied by the test, so each test can
/// call `watch(context)` (and count builds) from a real element's build.
class _WatchProbe extends StatelessWidget {
  const _WatchProbe({required this.builder});

  final Widget Function(BuildContext context) builder;

  @override
  Widget build(BuildContext context) => builder(context);
}

/// Writes [value] into [target] during `initState` — i.e. while the
/// framework is inside `SchedulerPhase.persistentCallbacks` — to exercise
/// the deferred (post-frame) rebuild path.
class _WriteOnInit extends StatefulWidget {
  const _WriteOnInit({required this.target, required this.value});

  final Observable<int> target;
  final int value;

  @override
  State<_WriteOnInit> createState() => _WriteOnInitState();
}

class _WriteOnInitState extends State<_WriteOnInit> {
  @override
  void initState() {
    super.initState();
    widget.target.value = widget.value;
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  tearDown(ObserverConfig.reset);

  group('watch(context)', () {
    testWidgets('rebuilds only the element that read the observable', (
      tester,
    ) async {
      final Observable<int> a = Observable<int>(0);
      final Observable<int> b = Observable<int>(0);
      int buildsA = 0;
      int buildsB = 0;
      addTearDown(a.close);
      addTearDown(b.close);

      await tester.pumpWidget(
        _wrap(
          Column(
            children: <Widget>[
              _WatchProbe(
                builder: (BuildContext context) {
                  buildsA++;
                  return Text('a:${a.watch(context)}');
                },
              ),
              _WatchProbe(
                builder: (BuildContext context) {
                  buildsB++;
                  return Text('b:${b.watch(context)}');
                },
              ),
            ],
          ),
        ),
      );
      expect(buildsA, 1);
      expect(buildsB, 1);

      a.value = 1;
      await tester.pump();

      expect(buildsA, 2);
      expect(buildsB, 1, reason: "b's element must not rebuild for a");
      expect(find.text('a:1'), findsOneWidget);
      expect(find.text('b:0'), findsOneWidget);

      b.value = 5;
      await tester.pump();

      expect(buildsA, 2, reason: "a's element must not rebuild for b");
      expect(buildsB, 2);
      expect(find.text('b:5'), findsOneWidget);
    });

    testWidgets('re-discovers conditional dependencies between builds', (
      tester,
    ) async {
      final Observable<bool> useA = Observable<bool>(true);
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(100);
      int builds = 0;

      await tester.pumpWidget(
        _wrap(
          _WatchProbe(
            builder: (BuildContext context) {
              builds++;
              final int shown = useA.watch(context)
                  ? a.watch(context)
                  : b.watch(context);
              return Text('v:$shown');
            },
          ),
        ),
      );
      expect(builds, 1);
      expect(find.text('v:1'), findsOneWidget);

      useA.value = false;
      await tester.pump();
      expect(builds, 2);
      expect(find.text('v:100'), findsOneWidget);

      // The abandoned branch must have been unsubscribed on re-track.
      a.value = 999;
      await tester.pump();
      expect(builds, 2, reason: 'a is no longer a dependency');
      expect(a.hasListeners, isFalse);

      b.value = 200;
      await tester.pump();
      expect(builds, 3);
      expect(find.text('v:200'), findsOneWidget);
    });

    testWidgets(
      'multiple observables watched by one element → one rebuild per batch',
      (tester) async {
        final Observable<int> a = Observable<int>(1);
        final Observable<int> b = Observable<int>(2);
        int builds = 0;

        await tester.pumpWidget(
          _wrap(
            _WatchProbe(
              builder: (BuildContext context) {
                builds++;
                return Text('sum:${a.watch(context) + b.watch(context)}');
              },
            ),
          ),
        );
        expect(builds, 1);

        Observable.batch(() {
          a.value = 10;
          b.value = 20;
        });
        await tester.pump();

        expect(builds, 2, reason: 'one rebuild for the whole batch');
        expect(find.text('sum:30'), findsOneWidget);
      },
    );

    testWidgets(
      'notification after unmount is a no-op and cleans the subscriptions',
      (tester) async {
        final Observable<int> count = Observable<int>(0);
        await tester.pumpWidget(
          _wrap(
            _WatchProbe(
              builder: (BuildContext context) =>
                  Text('c:${count.watch(context)}'),
            ),
          ),
        );
        expect(count.hasListeners, isTrue);

        await tester.pumpWidget(_wrap(const SizedBox.shrink()));

        // First write after unmount: must not throw, must not rebuild
        // anything, and — per the documented lazy cleanup — must release
        // every subscription of the dead element.
        expect(() => count.value = 1, returnsNormally);
        expect(count.hasListeners, isFalse);

        // Subsequent writes are equally inert.
        expect(() => count.value = 2, returnsNormally);
        await tester.pump();
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'change during persistentCallbacks defers the rebuild past the frame',
      (tester) async {
        final Observable<int> count = Observable<int>(0);
        int builds = 0;

        Widget tree({required bool withWriter}) => _wrap(
          Column(
            children: <Widget>[
              _WatchProbe(
                builder: (BuildContext context) {
                  builds++;
                  return Text('c:${count.watch(context)}');
                },
              ),
              if (withWriter) _WriteOnInit(target: count, value: 42),
            ],
          ),
        );

        await tester.pumpWidget(tree(withWriter: false));
        expect(builds, 1);

        // The writer's initState runs inside the build phase
        // (SchedulerPhase.persistentCallbacks): markNeedsBuild would throw
        // if called there, so the watcher must defer to a post-frame
        // callback instead.
        await tester.pumpWidget(tree(withWriter: true));
        expect(tester.takeException(), isNull);

        await tester.pump();
        expect(find.text('c:42'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'inside an Observer builder, watch delegates to the active tracking '
      'context (no element-level subscription)',
      (tester) async {
        final Observable<int> count = Observable<int>(0);
        int outerBuilds = 0;

        await tester.pumpWidget(
          _wrap(
            _WatchProbe(
              builder: (BuildContext context) {
                outerBuilds++;
                // `context` here is the OUTER element; watch inside the
                // Observer builder must report to the Observer, not
                // subscribe this element.
                return Observer(() => Text('c:${count.watch(context)}'));
              },
            ),
          ),
        );
        expect(outerBuilds, 1);

        count.value = 7;
        await tester.pump();

        expect(find.text('c:7'), findsOneWidget);
        expect(
          outerBuilds,
          1,
          reason:
              'only the Observer rebuilds; the outer element must not '
              'have been subscribed',
        );

        // Unmounting the Observer must leave no listener behind — proof
        // that the element-level registration path was never taken.
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));
        expect(count.hasListeners, isFalse);
      },
    );

    testWidgets('strictMode: watch outside build() throws ObserverError', (
      tester,
    ) async {
      final Observable<int> count = Observable<int>(0);
      await tester.pumpWidget(
        _wrap(
          _WatchProbe(
            builder: (BuildContext context) => const SizedBox.shrink(),
          ),
        ),
      );
      final BuildContext context = tester.element(find.byType(_WatchProbe));

      ObserverConfig.strictMode = true;
      expect(() => count.watch(context), throwsA(isA<ObserverError>()));

      // Without strictMode the same misuse only warns (and still returns
      // the value), matching the package-wide warning pattern.
      ObserverConfig.strictMode = false;
      expect(count.watch(context), 0);
    });

    testWidgets('fires onTrack inspector events labeled Watch(<widget>)', (
      tester,
    ) async {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors.add(recorder);
      final Observable<int> count = Observable<int>(0, name: 'count');

      await tester.pumpWidget(
        _wrap(
          _WatchProbe(
            builder: (BuildContext context) =>
                Text('c:${count.watch(context)}'),
          ),
        ),
      );

      final List<TrackEvent> tracks = recorder.events
          .whereType<TrackEvent>()
          .toList();
      expect(tracks, isNotEmpty);
      expect(tracks.first.trackerLabel, 'Watch(_WatchProbe)');
      expect(tracks.first.label, contains('count'));
    });
  });
}
