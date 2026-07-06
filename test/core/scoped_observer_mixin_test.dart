import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

/// Pure-Dart tests for `ScopedObserverMixin`: a plain controller class, no
/// widgets, no Flutter binding. (`ObserverStateMixin`, refactored in 1.4.0
/// to run on the same `ReactiveScope`, keeps its own unchanged suite in
/// `test/widgets/observer_state_mixin_test.dart`.)
class _CounterController with ScopedObserverMixin {
  _CounterController() {
    scoped(() {
      effect(() {
        effectRuns++;
        a.value;
      });
      ever(b, everSeen.add);
    });
    autoDispose(() => manualDisposeCalls++);
  }

  final Observable<int> a = Observable<int>(1);
  final Observable<int> b = Observable<int>(2);

  late final Computed<int> total = scoped(
    () => Computed<int>(() => a.value + b.value),
  );

  int effectRuns = 0;
  int manualDisposeCalls = 0;
  final List<int> everSeen = <int>[];

  void close() => disposeScope();
}

void main() {
  tearDown(ObserverConfig.reset);

  group('ScopedObserverMixin', () {
    test('resources created via the mixin API die on disposeScope()', () {
      final _CounterController controller = _CounterController();
      expect(controller.effectRuns, 1);
      expect(controller.total.value, 3);

      controller.a.value = 2;
      controller.b.value = 3;
      expect(controller.effectRuns, 2);
      expect(controller.everSeen, <int>[3]);
      expect(controller.total.value, 5);

      controller.close();

      expect(controller.isScopeDisposed, isTrue);
      expect(controller.total.isClosed, isTrue);
      expect(controller.manualDisposeCalls, 1);
      expect(controller.a.hasListeners, isFalse);
      expect(controller.b.hasListeners, isFalse);

      controller.a.value = 10;
      controller.b.value = 20;
      expect(controller.effectRuns, 2);
      expect(controller.everSeen, <int>[3]);
    });

    test('disposeScope() is idempotent', () {
      final _CounterController controller = _CounterController();
      controller.close();
      expect(controller.close, returnsNormally);
      expect(controller.manualDisposeCalls, 1);
    });

    test('isScopeDisposed is false until disposeScope() is called', () {
      final _CounterController controller = _CounterController();
      expect(controller.isScopeDisposed, isFalse);
      controller.close();
      expect(controller.isScopeDisposed, isTrue);
    });

    test('the exposed scope is the one the mixin registers into', () {
      final _CounterController controller = _CounterController();
      int calls = 0;
      controller.scope.add(() => calls++);
      controller.close();
      expect(calls, 1);
    });
  });
}
