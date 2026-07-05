import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/computed.dart';
import 'package:all_observer/src/observable/observable.dart';

/// Fase 0 — Validação do grafo: prova (ou refuta) que o grafo de
/// dependências atual é glitch-free, antes de qualquer feature nova ser
/// construída em cima dele (ver prompt de evolução v1.x → v2).
///
/// Phase 0 — Graph validation: proves (or disproves) that the current
/// dependency graph is glitch-free, before any new feature is built on top
/// of it.
void main() {
  group('Fase 0 — Diamond problem', () {
    test(
      'listener de d é notificado exatamente uma vez ao escrever em a',
      () {
        final Observable<int> a = Observable<int>(1);
        final Computed<int> b = Computed<int>(() => a.value + 1, name: 'b');
        final Computed<int> c = Computed<int>(() => a.value * 2, name: 'c');
        final Computed<int> d = Computed<int>(
          () => b.value + c.value,
          name: 'd',
        );

        int dNotifications = 0;
        final List<int> observedDValues = <int>[];
        d.addListener(() {
          dNotifications++;
          observedDValues.add(d.value);
        });

        // Warm up laziness before asserting on the write below.
        expect(d.value, b.value + c.value);

        a.value = 10;

        expect(
          dNotifications,
          1,
          reason: 'd deve notificar exatamente uma vez por escrita em a',
        );
        expect(d.value, 11 + 20);
        expect(observedDValues, <int>[31]);
      },
    );

    test('d nunca é observado em estado intermediário inconsistente', () {
      final Observable<int> a = Observable<int>(1);
      final Computed<int> b = Computed<int>(() => a.value + 1, name: 'b');
      final Computed<int> c = Computed<int>(() => a.value * 2, name: 'c');
      final Computed<int> d = Computed<int>(
        () => b.value + c.value,
        name: 'd',
      );

      final List<int> observedDuringNotify = <int>[];
      d.addListener(() {
        // Se b e c não estivessem ambos assentados no valor final aqui,
        // d.value refletiria um estado misto (glitch).
        observedDuringNotify.add(d.value);
      });

      expect(d.value, 4); // warm-up: b=2, c=2

      a.value = 5;

      // b=6, c=10 => d=16 é o único valor consistente possível.
      expect(observedDuringNotify, <int>[16]);
    });

    test('b, c e d recomputam no máximo uma vez cada por escrita em a', () {
      final Observable<int> a = Observable<int>(1);
      int bRuns = 0;
      int cRuns = 0;
      int dRuns = 0;
      final Computed<int> b = Computed<int>(() {
        bRuns++;
        return a.value + 1;
      }, name: 'b');
      final Computed<int> c = Computed<int>(() {
        cRuns++;
        return a.value * 2;
      }, name: 'c');
      final Computed<int> d = Computed<int>(() {
        dRuns++;
        return b.value + c.value;
      }, name: 'd');

      d.addListener(() {});
      expect(d.value, 4);
      bRuns = 0;
      cRuns = 0;
      dRuns = 0;

      a.value = 7;

      expect(bRuns, 1);
      expect(cRuns, 1);
      expect(dRuns, 1);
    });
  });

  group('Fase 0 — Computed em cadeia (a -> b -> c -> d)', () {
    test('escrita em a recomputa cada nível exatamente uma vez, em ordem', () {
      final Observable<int> a = Observable<int>(1);
      final List<String> recomputeOrder = <String>[];

      final Computed<int> b = Computed<int>(() {
        recomputeOrder.add('b');
        return a.value + 1;
      }, name: 'b');
      final Computed<int> c = Computed<int>(() {
        recomputeOrder.add('c');
        return b.value + 1;
      }, name: 'c');
      final Computed<int> d = Computed<int>(() {
        recomputeOrder.add('d');
        return c.value + 1;
      }, name: 'd');

      d.addListener(() {});
      expect(d.value, 4); // warm-up
      recomputeOrder.clear();

      a.value = 100;

      expect(recomputeOrder, <String>['b', 'c', 'd']);
      expect(d.value, 103);
    });
  });

  group('Fase 0 — Computed que corta propagação', () {
    test(
      'b recomputa mas não muda; nada downstream de b recomputa',
      () {
        final Observable<int> a = Observable<int>(1);
        int bRuns = 0;
        int downstreamRuns = 0;
        final Computed<bool> b = Computed<bool>(() {
          bRuns++;
          return a.value > 10;
        }, name: 'b');
        final Computed<String> downstream = Computed<String>(() {
          downstreamRuns++;
          return b.value ? 'big' : 'small';
        }, name: 'downstream');

        downstream.addListener(() {});
        expect(downstream.value, 'small');
        bRuns = 0;
        downstreamRuns = 0;

        a.value = 5; // 1 -> 5, ainda <= 10: b recomputa, valor não muda.

        expect(bRuns, 1, reason: 'b deve recomputar ao mudar a dependência');
        expect(
          downstreamRuns,
          0,
          reason:
              'downstream não deve recomputar: b não mudou de valor '
              '(change-filtering)',
        );
        expect(downstream.value, 'small');
      },
    );
  });

  group('Fase 0 — Dependências dinâmicas em Computed', () {
    test(
      'branch condicional troca de dependência sem leak nem notificação '
      'fantasma',
      () {
        final Observable<bool> useA = Observable<bool>(true);
        final Observable<int> a = Observable<int>(1, name: 'a');
        final Observable<int> b = Observable<int>(100, name: 'b');

        int computeRuns = 0;
        final Computed<int> derived = Computed<int>(() {
          computeRuns++;
          return useA.value ? a.value : b.value;
        }, name: 'derived');

        int notifications = 0;
        derived.addListener(() => notifications++);

        expect(derived.value, 1);
        expect(a.hasListeners, isTrue);
        expect(b.hasListeners, isFalse);

        // Troca para o branch de b.
        useA.value = false;
        expect(derived.value, 100);
        expect(notifications, 1);
        expect(
          a.hasListeners,
          isFalse,
          reason: 'a deve ser desinscrito ao trocar de branch (sem leak)',
        );
        expect(b.hasListeners, isTrue);

        notifications = 0;
        computeRuns = 0;

        // Escrever em a (branch antigo) não deve gerar notificação
        // fantasma nem recompute, já que derived não depende mais dele.
        a.value = 999;
        expect(notifications, 0);
        expect(computeRuns, 0);

        // Escrever em b (branch atual) deve notificar normalmente.
        b.value = 200;
        expect(derived.value, 200);
        expect(notifications, 1);
      },
    );
  });
}
