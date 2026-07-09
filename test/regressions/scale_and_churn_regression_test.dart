import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _app(Widget child) => MaterialApp(home: Scaffold(body: child));

void main() {
  testWidgets('500 independent Observers release every subscription', (
    WidgetTester tester,
  ) async {
    final List<Observable<int>> values = List<Observable<int>>.generate(
      500,
      (int index) => Observable<int>(index),
    );

    await tester.pumpWidget(
      _app(
        SingleChildScrollView(
          child: Column(
            children: values.indexed.map(((int, Observable<int>) entry) {
              return Observer(() => Text('${entry.$1}:${entry.$2.value}'));
            }).toList(),
          ),
        ),
      ),
    );
    expect(values.every((Observable<int> value) => value.hasListeners), isTrue);

    await tester.pumpWidget(_app(const SizedBox()));

    expect(
      values.every((Observable<int> value) => !value.hasListeners),
      isTrue,
    );
    expect(tester.takeException(), isNull);
    for (final Observable<int> value in values) {
      value.close();
    }
  });

  testWidgets('200 mount-update-unmount cycles leave no listener behind', (
    WidgetTester tester,
  ) async {
    final Observable<int> value = Observable<int>(0);

    for (int cycle = 0; cycle < 200; cycle++) {
      await tester.pumpWidget(_app(Observer(() => Text('${value.value}'))));
      expect(value.hasListeners, isTrue, reason: 'mount cycle $cycle');

      value.value++;
      await tester.pump();
      await tester.pumpWidget(_app(const SizedBox()));
      expect(value.hasListeners, isFalse, reason: 'unmount cycle $cycle');
    }

    expect(tester.takeException(), isNull);
    value.close();
  });

  test('1000 Computeds detach cleanly from one upstream Observable', () {
    final Observable<int> source = Observable<int>(1);
    final List<Computed<int>> derived = List<Computed<int>>.generate(
      1000,
      (int index) => Computed<int>(() => source.value + index),
    );

    for (int index = 0; index < derived.length; index++) {
      expect(derived[index].value, index + 1);
    }
    expect(source.hasListeners, isTrue);

    source.value = 2;
    expect(derived.last.value, 1001);

    for (final Computed<int> computed in derived) {
      computed.close();
    }
    expect(source.hasListeners, isFalse);
    source.close();
  });

  test('closing during notification keeps the current snapshot consistent', () {
    final Observable<int> source = Observable<int>(0);
    final List<String> calls = <String>[];
    source.listen((int _) {
      calls.add('first');
      source.close();
    });
    source.listen((int _) => calls.add('second'));

    expect(() => source.value = 1, returnsNormally);
    expect(calls, <String>['first', 'second']);
    expect(source.isClosed, isTrue);
    expect(source.hasListeners, isFalse);

    source.value = 2;
    expect(calls, <String>['first', 'second']);
  });
}
