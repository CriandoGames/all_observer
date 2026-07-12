// Integration tests for engine v2 Fase 2: CoreObservable/CoreComputed
// running on the public ReactiveEngine graph, through the registry bridge.
// The pre-existing suites (computed_graph_test, core tests, widget tests)
// remain the regression contract; these tests target only the NEW
// engine-specific behaviors.
//
// Testes de integração do motor v2 Fase 2: CoreObservable/CoreComputed
// rodando sobre o grafo público do ReactiveEngine, através da ponte de
// registry. As suítes pré-existentes (computed_graph_test, testes de core,
// de widget) continuam sendo o contrato de regressão; estes testes cobrem
// apenas os comportamentos NOVOS específicos do motor.
import 'package:all_observer/core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('engine v2 — computed sobre o grafo do motor', () {
    test('computed-of-computed stays glitch-free with one notification', () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final CoreComputed<int> b = CoreComputed<int>(() => a.value + 1);
      final CoreComputed<int> c = CoreComputed<int>(() => a.value * 2);
      final CoreComputed<int> d = CoreComputed<int>(() => b.value + c.value);

      final List<int> seen = <int>[];
      d.listen(seen.add);

      a.value = 1;
      expect(seen, <int>[4]); // (1+1) + (1*2), nunca uma mistura obsoleta
      a.value = 2;
      expect(seen, <int>[4, 7]);
    });

    test('a live computed settles eagerly once per write, listeners or not '
        '(pre-engine parity)', () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      int computes = 0;
      final CoreComputed<int> c = CoreComputed<int>(() {
        computes++;
        return a.value * 10;
      });

      expect(c.value, 0);
      expect(computes, 1);

      a.value = 1;
      a.value = 2;
      a.value = 3;
      // One settle per flushed write — the long-standing contract.
      // Uma estabilização por escrita liberada — o contrato de longa data.
      expect(computes, 4);

      expect(c.value, 30);
      expect(computes, 4); // a leitura não recomputa nada já fresco
    });

    test('custom equals acts as a firewall for listeners downstream', () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final CoreComputed<List<int>> parity = CoreComputed<List<int>>(
        () => <int>[a.value % 2],
        equals: (List<int> x, List<int> y) => x.first == y.first,
      );
      int notifications = 0;
      parity.listen((_) => notifications++);

      a.value = 2; // paridade inalterada (0)
      a.value = 4;
      expect(notifications, 0);
      a.value = 5; // paridade vira 1
      expect(notifications, 1);
    });

    test('detaching the last listener does not break settling or reads '
        '(pre-engine parity)', () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      int computes = 0;
      final CoreComputed<int> c = CoreComputed<int>(() {
        computes++;
        return a.value + 1;
      });
      final ObservableSubscription sub = c.listen((_) {});
      expect(computes, 1);

      a.value = 1;
      expect(computes, 2);

      sub.cancel();
      a.value = 2;
      // Still settles eagerly (same as before the engine): only close()
      // stops a live computed.
      // Ainda se estabiliza ansiosamente (igual a antes do motor): só o
      // close() para um computed vivo.
      expect(computes, 3);
      expect(c.value, 3);
      expect(computes, 3);
    });

    test('batched writes settle to one notification with final values', () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final CoreObservable<int> b = CoreObservable<int>(0);
      final CoreComputed<int> sum = CoreComputed<int>(() => a.value + b.value);
      final List<int> seen = <int>[];
      sum.listen(seen.add);

      BatchScope.run(() {
        a.value = 1;
        b.value = 2;
        a.value = 5;
      });
      expect(seen, <int>[7]); // só o estado final, uma vez
    });

    test('self-dependency throws a descriptive ObserverCycleError', () {
      late final CoreComputed<int> c;
      c = CoreComputed<int>(() => c.value + 1, name: 'ouroboros');
      expect(() => c.value, throwsA(isA<ObserverCycleError>()));
    });

    test('conditional dependencies switch branches correctly', () {
      final CoreObservable<bool> cond = CoreObservable<bool>(true);
      final CoreObservable<int> a = CoreObservable<int>(1);
      final CoreObservable<int> b = CoreObservable<int>(100);
      int computes = 0;
      final CoreComputed<int> pick = CoreComputed<int>(() {
        computes++;
        return cond.value ? a.value : b.value;
      });
      final List<int> seen = <int>[];
      pick.listen(seen.add);

      b.value = 200; // ramo não lido / unread branch
      expect(seen, isEmpty);

      cond.value = false;
      expect(seen, <int>[200]);

      final int before = computes;
      a.value = 99; // agora é o ramo morto / now the dead branch
      expect(computes, before);
      expect(seen, <int>[200]);
    });

    test('close() keeps last value readable and stops all reactions', () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final CoreComputed<int> c = CoreComputed<int>(() => a.value + 1);
      int notifications = 0;
      c.listen((_) => notifications++);
      expect(c.value, 1);

      c.close();
      a.value = 10;
      expect(notifications, 0);
      expect(c.value, 1); // último valor congelado / last value frozen
      expect(c.isClosed, isTrue);
    });

    test('untracked() inside CoreComputed does not create engine links', () {
      final CoreObservable<int> tracked = CoreObservable<int>(1);
      final CoreObservable<int> ignored = CoreObservable<int>(10);
      int computes = 0;
      final CoreComputed<int> derived = CoreComputed<int>(() {
        computes++;
        return tracked.value + untracked(() => ignored.value);
      });

      expect(derived.value, 11);
      expect(computes, 1);

      ignored.value = 20;
      expect(computes, 1);
      expect(derived.value, 11);
      expect(computes, 1);

      tracked.value = 2;
      expect(derived.value, 22);
      expect(computes, 2);

      expect(tracked.registry.engineNode!.subs, isNotNull);
      expect(ignored.registry.engineNode, isNull);
    });

    test('CoreComputed.close() during another recompute is safe', () {
      final CoreObservable<int> source = CoreObservable<int>(0);
      final CoreComputed<int> closing = CoreComputed<int>(
        () => source.value + 1,
      );
      final CoreComputed<int> survivor = CoreComputed<int>(
        () => source.value + 10,
      );
      late final CoreComputed<int> owner;
      owner = CoreComputed<int>(() {
        final int value = source.value;
        if (value == 1) {
          closing.close();
        }
        return value + closing.value + survivor.value;
      });

      final List<int> seen = <int>[];
      owner.listen(seen.add);
      expect(owner.value, 11);

      source.value = 1;

      expect(closing.isClosed, isTrue);
      expect(seen, <int>[13]);

      source.value = 2;

      expect(owner.value, 15);
      expect(survivor.value, 12);
      expect(seen, <int>[13, 15]);
    });

    test('value reverted inside same batch does not notify downstream', () {
      final CoreObservable<int> source = CoreObservable<int>(0);
      int computes = 0;
      final CoreComputed<int> derived = CoreComputed<int>(() {
        computes++;
        return source.value;
      });
      int notifications = 0;
      derived.listen((_) => notifications++);

      expect(derived.value, 0);
      computes = 0;

      BatchScope.run(() {
        source.value = 1;
        source.value = 0;
      });

      expect(derived.value, 0);
      expect(computes, 1);
      expect(notifications, 0);
    });
  });
}
