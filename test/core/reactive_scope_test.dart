import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';
import 'package:all_observer/src/core/typedefs.dart';

/// Pure-Dart tests for `ReactiveScope`: no widgets, no Flutter binding —
/// only the reactive engine, following the pattern of the other
/// `test/core/` suites.
void main() {
  tearDown(ObserverConfig.reset);

  group('ReactiveScope', () {
    test('Computed created inside run() is closed by dispose()', () {
      final Observable<int> a = Observable<int>(1);
      final Observable<int> b = Observable<int>(2);
      final ReactiveScope scope = ReactiveScope(name: 'computed');

      late final Computed<int> total;
      scope.run(() {
        total = Computed<int>(() => a.value + b.value);
      });
      // Force the lazy first compute so the Computed subscribes to a/b.
      expect(total.value, 3);
      expect(a.hasListeners, isTrue);

      scope.dispose();
      expect(total.isClosed, isTrue);
      expect(
        a.hasListeners,
        isFalse,
        reason: 'closing the Computed must unsubscribe from its deps',
      );
    });

    test('effect created inside run() is canceled by dispose()', () {
      final Observable<int> count = Observable<int>(0);
      final ReactiveScope scope = ReactiveScope(name: 'effect');
      int runs = 0;

      scope.run(() {
        effect(() {
          runs++;
          count.value;
        });
      });
      expect(runs, 1);
      count.value = 1;
      expect(runs, 2);

      scope.dispose();
      expect(count.hasListeners, isFalse);
      count.value = 2;
      expect(runs, 2, reason: 'a scope-disposed effect must never run again');
    });

    test('workers created inside run() are disposed by dispose()', () {
      final Observable<int> source = Observable<int>(0);
      final ReactiveScope scope = ReactiveScope(name: 'workers');
      final List<int> seenEver = <int>[];
      final List<int> seenOnce = <int>[];

      late final Worker everWorker;
      scope.run(() {
        everWorker = ever(source, seenEver.add);
        once(source, seenOnce.add);
      });
      source.value = 1;
      expect(seenEver, <int>[1]);
      expect(seenOnce, <int>[1]);

      scope.dispose();
      expect(everWorker.isDisposed, isTrue);
      source.value = 2;
      expect(seenEver, <int>[1], reason: 'ever must stop after scope dispose');
      expect(seenOnce, <int>[1]);
    });

    test('dispose() runs registered disposers in LIFO order', () {
      final ReactiveScope scope = ReactiveScope(name: 'lifo');
      final List<String> order = <String>[];
      scope.add(() => order.add('first'));
      scope.add(() => order.add('second'));
      scope.add(() => order.add('third'));

      scope.dispose();
      expect(order, <String>['third', 'second', 'first']);
    });

    test('nested scopes: disposing the parent disposes the child', () {
      final ReactiveScope parent = ReactiveScope(name: 'parent');
      late final ReactiveScope child;
      final Observable<int> count = Observable<int>(0);
      int childRuns = 0;

      parent.run(() {
        child = ReactiveScope(name: 'child');
        child.run(() {
          effect(() {
            childRuns++;
            count.value;
          });
        });
      });
      expect(childRuns, 1);

      parent.dispose();
      expect(child.isDisposed, isTrue);
      count.value = 1;
      expect(childRuns, 1, reason: 'parent dispose must tear the child down');
    });

    test('nested scopes: disposing the child does not affect the parent', () {
      final ReactiveScope parent = ReactiveScope(name: 'parent');
      late final ReactiveScope child;
      final Observable<int> count = Observable<int>(0);
      int parentRuns = 0;

      parent.run(() {
        effect(() {
          parentRuns++;
          count.value;
        });
        child = ReactiveScope(name: 'child');
      });

      child.dispose();
      expect(parent.isDisposed, isFalse);
      count.value = 1;
      expect(parentRuns, 2, reason: 'child dispose must not touch the parent');

      // Parent dispose afterwards is still safe: the child's registered
      // dispose is idempotent.
      expect(parent.dispose, returnsNormally);
      expect(parent.isDisposed, isTrue);
    });

    test('dispose() is idempotent', () {
      final ReactiveScope scope = ReactiveScope(name: 'idempotent');
      int calls = 0;
      scope.add(() => calls++);

      scope.dispose();
      scope.dispose();
      expect(calls, 1);
      expect(scope.isDisposed, isTrue);
    });

    test('creation outside any scope registers nothing (opt-in)', () {
      final Observable<int> a = Observable<int>(1);
      final ReactiveScope scope = ReactiveScope(name: 'unrelated');

      // Created OUTSIDE scope.run: the scope must not own any of it.
      final Computed<int> doubled = Computed<int>(() => a.value * 2);
      int runs = 0;
      final Disposer disposeEffect = effect(() {
        runs++;
        a.value;
      });
      final Worker worker = ever(a, (_) {});

      expect(doubled.value, 2);
      scope.dispose();

      expect(doubled.isClosed, isFalse);
      expect(worker.isDisposed, isFalse);
      a.value = 2;
      expect(runs, 2, reason: 'out-of-scope effect must keep running');
      expect(doubled.value, 4);

      disposeEffect();
      worker.dispose();
      doubled.close();
    });

    test('run() restores the previously active scope, even on throw', () {
      final ReactiveScope outer = ReactiveScope(name: 'outer');
      final ReactiveScope inner = ReactiveScope(name: 'inner');
      ReactiveScope? duringInner;
      ReactiveScope? afterInner;

      outer.run(() {
        expect(
          () => inner.run(() {
            duringInner = ReactiveScope.current;
            throw StateError('boom');
          }),
          throwsStateError,
        );
        afterInner = ReactiveScope.current;
      });

      expect(duringInner, same(inner));
      expect(afterInner, same(outer));
      expect(ReactiveScope.current, isNull);
    });

    test(
      'add() after dispose() warns and disposes the resource immediately',
      () {
        final RecordingInspector recorder = RecordingInspector();
        ObserverConfig.inspectors.add(recorder);
        final ReactiveScope scope = ReactiveScope(name: 'dead');
        scope.dispose();

        int calls = 0;
        scope.add(() => calls++);

        expect(calls, 1, reason: 'resource must be disposed, never leaked');
        expect(
          recorder.events.whereType<WarningEvent>().where(
            (WarningEvent e) => e.label.contains('ReactiveScope(dead)'),
          ),
          hasLength(1),
        );
      },
    );

    test('add() after dispose() throws ObserverError under strictMode', () {
      ObserverConfig.strictMode = true;
      final ReactiveScope scope = ReactiveScope(name: 'strict');
      scope.dispose();

      int calls = 0;
      expect(() => scope.add(() => calls++), throwsA(isA<ObserverError>()));
      expect(
        calls,
        1,
        reason: 'even under strictMode the resource is disposed first',
      );
    });

    test('onScopeDispose reaches the inspector with the correct count', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors.add(recorder);
      final Observable<int> a = Observable<int>(1);
      final ReactiveScope scope = ReactiveScope(name: 'inspected');

      scope.run(() {
        Computed<int>(() => a.value * 2);
        effect(() => a.value);
        ever(a, (_) {});
      });
      scope.dispose();
      scope.dispose(); // idempotent: must not dispatch a second event

      final List<ScopeDisposeEvent> events = recorder.events
          .whereType<ScopeDisposeEvent>()
          .toList();
      expect(events, hasLength(1));
      expect(events.single.label, 'ReactiveScope(inspected)');
      expect(events.single.disposedCount, 3);
    });

    test('a throwing disposer never blocks the remaining disposers', () {
      final ReactiveScope scope = ReactiveScope(name: 'throwing');
      final List<String> order = <String>[];
      // Capture the isolated report so it does not fail the test run.
      final List<Object> reported = <Object>[];
      final void Function(
        Object error,
        StackTrace stackTrace, {
        required String library,
        required String context,
      })?
      previousReporter = CoreErrorReporting.reporter;
      CoreErrorReporting.reporter =
          (
            Object error,
            StackTrace stackTrace, {
            required String library,
            required String context,
          }) {
            reported.add(error);
          };
      addTearDown(() => CoreErrorReporting.reporter = previousReporter);

      scope.add(() => order.add('first'));
      scope.add(() => throw StateError('boom'));
      scope.add(() => order.add('third'));

      scope.dispose();
      expect(order, <String>['third', 'first']);
      expect(reported.single, isA<StateError>());
    });
  });
}
