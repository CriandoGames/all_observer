import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/dependency_tracker.dart';
import 'package:all_observer/src/core/listener_registry.dart';

void main() {
  group('DependencyTracker', () {
    test('current is null with no active context', () {
      expect(DependencyTracker.current, isNull);
    });

    test('track pushes and pops the context around action', () {
      final TrackingContext context = TrackingContext(() {});
      TrackingContext? insideContext;
      DependencyTracker.track(context, () {
        insideContext = DependencyTracker.current;
      });
      expect(insideContext, same(context));
      expect(DependencyTracker.current, isNull);
    });

    test('nested tracking restores the outer context (stack behavior)', () {
      final TrackingContext outer = TrackingContext(() {});
      final TrackingContext inner = TrackingContext(() {});
      TrackingContext? duringInner;
      TrackingContext? afterInnerPopped;

      DependencyTracker.track(outer, () {
        DependencyTracker.track(inner, () {
          duringInner = DependencyTracker.current;
        });
        afterInnerPopped = DependencyTracker.current;
      });

      expect(duringInner, same(inner));
      expect(afterInnerPopped, same(outer));
      expect(DependencyTracker.current, isNull);
    });

    test('stack pop is guaranteed even if action throws', () {
      final TrackingContext context = TrackingContext(() {});
      expect(
        () => DependencyTracker.track(context, () => throw StateError('x')),
        throwsStateError,
      );
      expect(DependencyTracker.current, isNull);
    });

    test('reportRead registers a listener and disposer once per registry', () {
      final ListenerRegistry registry = ListenerRegistry();
      final TrackingContext context = TrackingContext(() {});
      DependencyTracker.track(context, () {
        DependencyTracker.reportRead(registry);
        DependencyTracker.reportRead(registry);
      });
      expect(registry.length, 1);
      expect(context.disposers, hasLength(1));
      expect(context.readCount, 2);
    });

    test('reportRead registers the context onDependencyChanged callback, '
        'not some other listener, so notifying the registry triggers it', () {
      final ListenerRegistry registry = ListenerRegistry();
      int rebuilds = 0;
      final TrackingContext context = TrackingContext(() => rebuilds++);
      DependencyTracker.track(
        context,
        () => DependencyTracker.reportRead(registry),
      );
      registry.notifyAll();
      expect(rebuilds, 1);
    });

    test('reportRead without an active context does nothing', () {
      final ListenerRegistry registry = ListenerRegistry();
      DependencyTracker.reportRead(registry);
      expect(registry.hasListeners, isFalse);
    });
  });
}
