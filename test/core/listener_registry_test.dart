import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/core/listener_registry.dart';

void main() {
  group('ListenerRegistry', () {
    test('add registers a listener and notifyAll invokes it', () {
      final ListenerRegistry registry = ListenerRegistry();
      int calls = 0;
      registry.add(() => calls++);
      registry.notifyAll();
      expect(calls, 1);
    });

    test('adding the same listener twice registers it once', () {
      final ListenerRegistry registry = ListenerRegistry();
      void listener() {}
      registry.add(listener);
      registry.add(listener);
      expect(registry.length, 1);
    });

    test('disposer returned by add removes the listener', () {
      final ListenerRegistry registry = ListenerRegistry();
      int calls = 0;
      final void Function() dispose = registry.add(() => calls++);
      dispose();
      registry.notifyAll();
      expect(calls, 0);
      expect(registry.hasListeners, isFalse);
    });

    test('listener mutating the registry during notification does not '
        'affect the current notification pass', () {
      final ListenerRegistry registry = ListenerRegistry();
      final List<String> order = <String>[];
      late void Function() disposeSecond;
      void first() {
        order.add('first');
        disposeSecond();
      }

      void second() => order.add('second');
      registry.add(first);
      disposeSecond = registry.add(second);

      registry.notifyAll();

      expect(order, <String>['first', 'second']);
      expect(registry.hasListeners, isTrue);
      expect(registry.length, 1);
    });

    test('clear removes all listeners', () {
      final ListenerRegistry registry = ListenerRegistry();
      registry.add(() {});
      registry.add(() {});
      registry.clear();
      expect(registry.hasListeners, isFalse);
    });

    test('notifyAll on an empty registry is a no-op', () {
      final ListenerRegistry registry = ListenerRegistry();
      expect(() => registry.notifyAll(), returnsNormally);
    });
  });
}
