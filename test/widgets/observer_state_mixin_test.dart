import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/widgets/observer_state_mixin.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

class _Probe extends StatefulWidget {
  const _Probe({required this.source, required this.onEffectRun});

  final Observable<int> source;
  final void Function(int value) onEffectRun;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with ObserverStateMixin {
  int manualDisposeCalls = 0;

  @override
  void initState() {
    super.initState();
    autorun(() => widget.onEffectRun(widget.source.value));
    autoDispose(() => manualDisposeCalls++);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

void main() {
  group('ObserverStateMixin', () {
    testWidgets('autorun reacts to the observable and stops after unmount', (
      tester,
    ) async {
      final Observable<int> source = Observable<int>(1);
      final List<int> seen = <int>[];

      await tester.pumpWidget(
        _wrap(_Probe(source: source, onEffectRun: seen.add)),
      );
      expect(seen, <int>[1]);

      source.value = 2;
      await tester.pump();
      expect(seen, <int>[1, 2]);

      // Unmount the widget: the autorun effect must be disposed and
      // stop reacting to further changes.
      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      source.value = 3;
      await tester.pump();
      expect(seen, <int>[1, 2]);
    });

    testWidgets('autoDispose runs registered disposers on unmount', (
      tester,
    ) async {
      final Observable<int> source = Observable<int>(1);
      late _ProbeState state;

      await tester.pumpWidget(
        _wrap(_Probe(source: source, onEffectRun: (_) {})),
      );
      state = tester.state(find.byType(_Probe));
      expect(state.manualDisposeCalls, 0);

      await tester.pumpWidget(_wrap(const SizedBox.shrink()));
      expect(state.manualDisposeCalls, 1);
    });

    testWidgets(
      'autoDispose called after dispose() runs the disposer immediately',
      (tester) async {
        final Observable<int> source = Observable<int>(1);
        await tester.pumpWidget(
          _wrap(_Probe(source: source, onEffectRun: (_) {})),
        );
        final _ProbeState state = tester.state(find.byType(_Probe));
        await tester.pumpWidget(_wrap(const SizedBox.shrink()));

        int calls = 0;
        state.autoDispose(() => calls++);
        expect(calls, 1);
      },
    );
  });
}
