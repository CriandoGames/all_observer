import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

void main() {
  testWidgets('public API: Observable + Observer rebuild end to end', (
    tester,
  ) async {
    final ObservableInt count = 0.obs;
    await tester.pumpWidget(
      MaterialApp(home: Observer(() => Text('${count.value}'))),
    );
    expect(find.text('0'), findsOneWidget);
    count.value++;
    await tester.pump();
    expect(find.text('1'), findsOneWidget);
  });

  test('public API: ValueListenable interop', () {
    final ObservableInt count = 0.obs;
    expect(count, isA<ValueListenable<int>>());
  });
}
