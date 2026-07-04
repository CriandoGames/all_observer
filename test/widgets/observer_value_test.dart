import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable_extensions.dart';
import 'package:all_observer/src/observable/observable_types.dart';
import 'package:all_observer/src/widgets/observer_value.dart';

void main() {
  testWidgets('ObserverValue rebuilds when its owned observable changes', (
    tester,
  ) async {
    final ObservableBool active = false.obs;
    await tester.pumpWidget(
      MaterialApp(
        home: ObserverValue<ObservableBool>(
          (data) => Text(data.value ? 'on' : 'off'),
          active,
        ),
      ),
    );
    expect(find.text('off'), findsOneWidget);
    active.value = true;
    await tester.pump();
    expect(find.text('on'), findsOneWidget);
  });
}
