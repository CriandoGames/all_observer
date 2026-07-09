import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _User {
  _User(this.name);

  String name;
}

void main() {
  setUp(ObserverConfig.reset);
  tearDown(ObserverConfig.reset);

  group('closed Observable regressions', () {
    test('write after close is a no-op and close is idempotent', () {
      final Observable<int> count = Observable<int>(1);
      int notifications = 0;
      count.listen((int _) => notifications++);

      count.close();
      expect(count.close, returnsNormally);
      expect(() => count.value = 2, returnsNormally);

      expect(count.value, 1);
      expect(notifications, 0);
      expect(count.hasListeners, isFalse);
    });

    test('refresh after close neither notifies nor throws', () {
      final Observable<List<int>> items = Observable<List<int>>(<int>[1]);
      int notifications = 0;
      items.listen((List<int> _) => notifications++);
      items.close();

      expect(items.refresh, returnsNormally);
      expect(notifications, 0);
      expect(items.hasListeners, isFalse);
    });

    test('listen after close returns an inactive subscription', () {
      final Observable<int> count = Observable<int>(0);
      count.close();
      int notifications = 0;

      final ObservableSubscription subscription = count.listen(
        (int _) => notifications++,
      );
      count
        ..value = 1
        ..refresh();

      expect(subscription.isActive, isFalse);
      expect(notifications, 0);
      expect(count.hasListeners, isFalse);
    });
  });

  group('ObservableList mutation regressions', () {
    test('each structural operation notifies once, including bulk addAll', () {
      final ObservableList<int> items = ObservableList<int>(<int>[1, 2]);
      int notifications = 0;
      items.listen(() => notifications++);

      items.add(3);
      expect(notifications, 1);
      items.addAll(<int>[4, 5, 6]);
      expect(notifications, 2);
      items[0] = 10;
      expect(notifications, 3);
      items.remove(2);
      expect(notifications, 4);
      items.clear();
      expect(notifications, 5);
      items.close();
    });

    test('internal object mutation is intentionally not automatic', () {
      final ObservableList<_User> users = ObservableList<_User>(<_User>[
        _User('old'),
      ]);
      int notifications = 0;
      users.listen(() => notifications++);

      users[0].name = 'mutated in place';
      expect(notifications, 0);

      users[0] = _User('replaced');
      expect(notifications, 1);
      expect(users[0].name, 'replaced');
      users.close();
    });
  });

  group('ReactiveScope disposal regressions', () {
    test('mixed resources stop reacting and custom disposers run in LIFO', () {
      final Observable<int> source = Observable<int>(1);
      final ReactiveScope scope = ReactiveScope(name: 'mixed');
      final List<String> disposalOrder = <String>[];
      int computes = 0;
      int effectRuns = 0;
      int manualRuns = 0;
      late CoreComputed<int> computed;

      scope.run(() {
        scope.add(() => disposalOrder.add('first'));
        computed = CoreComputed<int>(() {
          computes++;
          return source.value * 2;
        });
        effect(() {
          effectRuns++;
          source.value;
        });
        final ObservableSubscription subscription = source.listen(
          (int _) => manualRuns++,
        );
        scope.add(() {
          disposalOrder.add('last');
          subscription.cancel();
        });
      });
      expect(computed.value, 2);
      source.value = 2;
      expect(effectRuns, 2);
      expect(manualRuns, 1);

      scope.dispose();
      expect(scope.dispose, returnsNormally);
      expect(disposalOrder, <String>['last', 'first']);
      expect(computed.isClosed, isTrue);
      final int computesAfterDispose = computes;
      source.value = 3;
      expect(effectRuns, 2);
      expect(manualRuns, 1);
      expect(computes, computesAfterDispose);
      source.close();
    });

    test('resource added to a disposed scope is disposed immediately', () {
      final ReactiveScope scope = ReactiveScope(name: 'disposed');
      scope.dispose();
      bool disposed = false;

      scope.add(() => disposed = true);

      expect(disposed, isTrue);
    });

    test('strict mode still disposes late resource before throwing', () {
      ObserverConfig.strictMode = true;
      final ReactiveScope scope = ReactiveScope(name: 'strict-disposed');
      scope.dispose();
      bool disposed = false;

      expect(
        () => scope.add(() => disposed = true),
        throwsA(isA<ObserverError>()),
      );
      expect(disposed, isTrue);
    });
  });

  test('CoreComputed close releases conditional dependencies permanently', () {
    final CoreObservable<bool> useA = CoreObservable<bool>(true);
    final CoreObservable<int> a = CoreObservable<int>(1);
    final CoreObservable<int> b = CoreObservable<int>(2);
    int computes = 0;
    int notifications = 0;
    final CoreComputed<int> selected = CoreComputed<int>(() {
      computes++;
      return useA.value ? a.value : b.value;
    });
    selected.listen((int _) => notifications++);
    expect(selected.value, 1);
    expect(a.hasListeners, isTrue);
    expect(b.hasListeners, isFalse);

    useA.value = false;
    expect(selected.value, 2);
    expect(a.hasListeners, isFalse);
    expect(b.hasListeners, isTrue);

    selected.close();
    expect(selected.close, returnsNormally);
    expect(a.hasListeners, isFalse);
    expect(b.hasListeners, isFalse);
    final int computesAfterClose = computes;

    a.value = 10;
    b.value = 20;
    useA.value = true;
    expect(computes, computesAfterClose);
    expect(notifications, 1);
    expect(selected.value, 2);
  });
}
