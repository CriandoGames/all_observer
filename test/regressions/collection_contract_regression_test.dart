import 'dart:math';

import 'package:all_observer/all_observer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ObservableList uncovered mutation contracts', () {
    test('length, removeAt and insert each mutate and notify once', () {
      final ObservableList<int?> items = ObservableList<int?>(<int?>[1, 2, 3]);
      int notifications = 0;
      items.listen(() => notifications++);

      items.length = 5;
      expect(items, <int?>[1, 2, 3, null, null]);
      expect(notifications, 1);

      expect(items.removeAt(1), 2);
      expect(notifications, 2);

      items.insert(1, 9);
      expect(items, <int?>[1, 9, 3, null, null]);
      expect(notifications, 3);
      items.close();
    });

    test('length, removeAt and insert are no-ops after close', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2, 3]);
      items.close();

      items.length = 1;
      expect(items.removeAt(1), 2);
      items.insert(1, 9);

      expect(items, <int>[1, 2, 3]);
    });
  });

  group('collection read tracking', () {
    testWidgets('ObservableSet iteration registers a reactive dependency', (
      WidgetTester tester,
    ) async {
      final ObservableSet<int> values = ObservableSet<int>(<int>{1, 2});
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Observer(
            () => Text(
              '${values.fold<int>(0, (int total, int value) => total + value)}',
            ),
          ),
        ),
      );
      expect(find.text('3'), findsOneWidget);

      values.add(3);
      await tester.pump();

      expect(find.text('6'), findsOneWidget);
      values.close();
    });

    testWidgets('ObservableSet lookup registers a reactive dependency', (
      WidgetTester tester,
    ) async {
      final ObservableSet<String> values = ObservableSet<String>(<String>{'a'});
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Observer(() => Text('${values.lookup('a')}')),
        ),
      );
      expect(find.text('a'), findsOneWidget);

      values.remove('a');
      await tester.pump();

      expect(find.text('null'), findsOneWidget);
      values.close();
    });
  });

  test('seeded list operation sequence stays equivalent to a Dart List', () {
    final Random random = Random(731);
    final List<int> model = <int>[];
    final ObservableList<int> observed = ObservableList<int>();
    int notifications = 0;
    observed.listen(() => notifications++);
    int expectedNotifications = 0;

    for (int step = 0; step < 1000; step++) {
      switch (random.nextInt(5)) {
        case 0:
          final int value = random.nextInt(100);
          model.add(value);
          observed.add(value);
          expectedNotifications++;
        case 1:
          final int value = random.nextInt(100);
          final int index = model.isEmpty
              ? 0
              : random.nextInt(model.length + 1);
          model.insert(index, value);
          observed.insert(index, value);
          expectedNotifications++;
        case 2:
          if (model.isNotEmpty) {
            final int index = random.nextInt(model.length);
            expect(observed.removeAt(index), model.removeAt(index));
            expectedNotifications++;
          }
        case 3:
          if (model.isNotEmpty) {
            final int index = random.nextInt(model.length);
            final int value = random.nextInt(100);
            model[index] = value;
            observed[index] = value;
            expectedNotifications++;
          }
        case 4:
          if (model.isNotEmpty) {
            model.clear();
            observed.clear();
            expectedNotifications++;
          }
      }
      expect(observed, model, reason: 'diverged at seeded step $step');
    }

    expect(notifications, expectedNotifications);
    observed.close();
  });

  test('seeded map operation sequence stays equivalent to a Dart Map', () {
    final Random random = Random(947);
    final Map<int, int> model = <int, int>{};
    final ObservableMap<int, int> observed = ObservableMap<int, int>();
    int notifications = 0;
    observed.listen(() => notifications++);
    int expectedNotifications = 0;

    for (int step = 0; step < 1000; step++) {
      final int key = random.nextInt(30);
      switch (random.nextInt(4)) {
        case 0:
          final int value = random.nextInt(100);
          final bool changes = !model.containsKey(key) || model[key] != value;
          model[key] = value;
          observed[key] = value;
          if (changes) {
            expectedNotifications++;
          }
        case 1:
          final bool existed = model.containsKey(key);
          expect(observed.remove(key), model.remove(key));
          if (existed) {
            expectedNotifications++;
          }
        case 2:
          final Map<int, int> additions = <int, int>{
            key: random.nextInt(100),
            (key + 1) % 30: random.nextInt(100),
          };
          model.addAll(additions);
          observed.addAll(additions);
          expectedNotifications++;
        case 3:
          if (model.isNotEmpty) {
            model.clear();
            observed.clear();
            expectedNotifications++;
          }
      }
      expect(observed, model, reason: 'map diverged at seeded step $step');
    }

    expect(notifications, expectedNotifications);
    observed.close();
  });

  test('seeded set operation sequence stays equivalent to a Dart Set', () {
    final Random random = Random(1151);
    final Set<int> model = <int>{};
    final ObservableSet<int> observed = ObservableSet<int>();
    int notifications = 0;
    observed.listen(() => notifications++);
    int expectedNotifications = 0;

    for (int step = 0; step < 1000; step++) {
      final int value = random.nextInt(50);
      switch (random.nextInt(4)) {
        case 0:
          final bool changed = model.add(value);
          expect(observed.add(value), changed);
          if (changed) {
            expectedNotifications++;
          }
        case 1:
          final bool changed = model.remove(value);
          expect(observed.remove(value), changed);
          if (changed) {
            expectedNotifications++;
          }
        case 2:
          final Set<int> additions = <int>{
            value,
            (value + 1) % 50,
            (value + 2) % 50,
          };
          final int lengthBefore = model.length;
          model.addAll(additions);
          observed.addAll(additions);
          if (model.length != lengthBefore) {
            expectedNotifications++;
          }
        case 3:
          if (model.isNotEmpty) {
            model.clear();
            observed.clear();
            expectedNotifications++;
          }
      }
      expect(observed, model, reason: 'set diverged at seeded step $step');
    }

    expect(notifications, expectedNotifications);
    observed.close();
  });
}
