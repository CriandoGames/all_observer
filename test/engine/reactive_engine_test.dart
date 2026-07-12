// Standalone tests for the public engine layer (`lib/engine.dart`, Fase 1
// of engine v2). Nothing here touches CoreObservable/CoreComputed — the
// engine is exercised through the minimal preset in `fixtures/mini_preset
// .dart`, which is also the design sketch for Fase 2.
//
// Testes independentes da camada pública do motor (`lib/engine.dart`, Fase
// 1 do motor v2). Nada aqui toca CoreObservable/CoreComputed — o motor é
// exercitado através do preset mínimo em `fixtures/mini_preset.dart`, que
// também é o rascunho de design da Fase 2.
import 'package:all_observer/engine.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures/mini_preset.dart';

void main() {
  setUp(resetMiniPreset);

  group('ReactiveEngine — basics', () {
    test('effect runs on creation and re-runs on writes', () {
      final MiniSignal<int> s = MiniSignal<int>(0);
      final List<int> seen = <int>[];
      final MiniEffect e = effect(() => seen.add(s.get()));

      expect(seen, <int>[0]);
      s.set(1);
      s.set(2);
      expect(seen, <int>[0, 1, 2]);
      expect(e.runs, 3);
    });

    test('stopped effect never re-runs', () {
      final MiniSignal<int> s = MiniSignal<int>(0);
      final MiniEffect e = effect(() => s.get());
      e.stop();
      s.set(1);
      expect(e.runs, 1);
    });

    test('writing an identical value does not re-run effects', () {
      final MiniSignal<int> s = MiniSignal<int>(5);
      final MiniEffect e = effect(() => s.get());
      s.set(5);
      expect(e.runs, 1);
    });
  });

  group('ReactiveEngine — lazy pull (computed)', () {
    test('an unread computed never recomputes, no matter how many writes', () {
      final MiniSignal<int> s = MiniSignal<int>(0);
      final MiniComputed<int> c = MiniComputed<int>(() => s.get() * 10);

      expect(c.get(), 0);
      expect(c.recomputes, 1);

      s.set(1);
      s.set(2);
      s.set(3);
      // Push phase only marked it pending — zero recomputes so far.
      // A fase push só o marcou como pending — zero recomputações até aqui.
      expect(c.recomputes, 1);

      expect(c.get(), 30);
      // One single pull recompute despite three writes.
      // Uma única recomputação pull apesar de três escritas.
      expect(c.recomputes, 2);
    });

    test('diamond (a -> b,c -> d): glitch-free, one effect run per write', () {
      final MiniSignal<int> a = MiniSignal<int>(0);
      final MiniComputed<int> b = MiniComputed<int>(() => a.get() + 1);
      final MiniComputed<int> c = MiniComputed<int>(() => a.get() * 2);
      final MiniComputed<int> d = MiniComputed<int>(() => b.get() + c.get());
      final List<int> seen = <int>[];
      final MiniEffect e = effect(() => seen.add(d.get()));

      expect(seen, <int>[1]); // (0+1) + (0*2)
      a.set(1);
      expect(seen, <int>[1, 4]); // (1+1) + (1*2) — never a stale mix
      a.set(2);
      expect(seen, <int>[1, 4, 7]);
      expect(e.runs, 3); // exactly one run per write / um run por escrita
    });

    test('deep chain (50k computeds): propagate/checkDirty never overflow', () {
      const int depth = 50000;
      final MiniSignal<int> root = MiniSignal<int>(0);
      MiniComputed<int> prev = MiniComputed<int>(() => root.get() + 1);
      prev.get(); // evaluate level by level / avalia nível a nível
      for (int i = 1; i < depth; i++) {
        final MiniComputed<int> p = prev;
        prev = MiniComputed<int>(() => p.get() + 1);
        prev.get();
      }
      final MiniComputed<int> tail = prev;

      expect(tail.get(), depth);
      // Push through 50k levels (iterative propagate), then pull back down
      // (iterative checkDirty) — both with the explicit EngineStack.
      // Push por 50 mil níveis (propagate iterativo), depois pull de volta
      // (checkDirty iterativo) — ambos com a EngineStack explícita.
      root.set(5);
      expect(tail.get(), depth + 5);
    });
  });

  group('ReactiveEngine — propagation cut (update() returning false)', () {
    test('default identity cut: computed landing on an identical value '
        'stops downstream', () {
      final MiniSignal<int> s = MiniSignal<int>(0);
      final MiniComputed<bool> gate = MiniComputed<bool>(() => s.get() >= 10);
      final MiniEffect e = effect(() => gate.get());

      expect(e.runs, 1);
      s.set(1);
      s.set(2);
      s.set(9);
      // gate recomputed (pulled by the queued effect's checkDirty) but its
      // value never changed, so the effect body never re-ran.
      // gate recomputou (puxado pelo checkDirty do effect enfileirado) mas
      // seu valor nunca mudou, então o corpo do effect nunca re-rodou.
      expect(e.runs, 1);
      s.set(10);
      expect(e.runs, 2);
    });

    test('custom equals cut: update() returning false acts as a firewall', () {
      final MiniSignal<int> s = MiniSignal<int>(0);
      // A fresh List each recompute — identical() would always say
      // "changed"; only the custom equals can cut here.
      // Uma List nova a cada recomputação — identical() sempre diria
      // "mudou"; só o equals customizado corta aqui.
      final MiniComputed<List<int>> parity = MiniComputed<List<int>>(
        () => <int>[s.get() % 2],
        equals: (List<int> a, List<int> b) => a.first == b.first,
      );
      final MiniEffect e = effect(() => parity.get());

      expect(e.runs, 1);
      s.set(2); // parity unchanged (0) / paridade inalterada (0)
      s.set(4);
      expect(e.runs, 1);
      s.set(5); // parity flips to 1 / paridade vira 1
      expect(e.runs, 2);
    });
  });

  group('ReactiveEngine — link reuse and dynamic dependencies', () {
    test('re-running with the same reads reuses the same link objects '
        '(zero churn)', () {
      final MiniSignal<int> s1 = MiniSignal<int>(0);
      final MiniSignal<int> s2 = MiniSignal<int>(0);
      final MiniEffect e = effect(() {
        s1.get();
        s2.get();
      });

      final ReactiveLink first = e.deps!;
      final ReactiveLink second = e.deps!.nextDep!;
      s1.set(1); // re-run re-tracks both deps / re-execução re-rastreia ambas
      expect(identical(e.deps, first), isTrue);
      expect(identical(e.deps!.nextDep, second), isTrue);
      expect(e.deps!.nextDep!.nextDep, isNull);
    });

    test('conditional reads: dropped branch is unlinked and stops '
        'triggering', () {
      final MiniSignal<bool> cond = MiniSignal<bool>(true);
      final MiniSignal<int> a = MiniSignal<int>(0);
      final MiniSignal<int> b = MiniSignal<int>(0);
      final MiniEffect e = effect(() {
        if (cond.get()) {
          a.get();
        } else {
          b.get();
        }
      });

      expect(e.runs, 1);
      b.set(1); // unread branch / ramo não lido
      expect(e.runs, 1);
      a.set(1);
      expect(e.runs, 2);

      cond.set(false); // switch branches / troca de ramo
      expect(e.runs, 3);
      expect(engine.unwatchedLog, contains(a)); // a lost its last subscriber

      a.set(99); // now the dead branch / agora o ramo morto
      expect(e.runs, 3);
      b.set(2);
      expect(e.runs, 4);
    });
  });

  group('ReactiveEngine — unwatched (automatic cleanup)', () {
    test(
      'computed releases its own deps when it loses its last subscriber',
      () {
        final MiniSignal<int> s = MiniSignal<int>(0);
        final MiniComputed<int> c = MiniComputed<int>(() => s.get() + 1);
        final MiniEffect e = effect(() => c.get());

        expect(s.subs, isNotNull); // s -> c edge alive / aresta s -> c viva
        e.stop();

        expect(engine.unwatchedLog, contains(c));
        // Auto-release: c dropped its own dependency on s.
        // Auto-liberação: c soltou sua própria dependência de s.
        expect(c.deps, isNull);
        expect(s.subs, isNull);

        // And a later read still works, recomputing fresh.
        // E uma leitura posterior ainda funciona, recomputando do zero.
        final int before = c.recomputes;
        s.set(10);
        expect(c.get(), 11);
        expect(c.recomputes, before + 1);
      },
    );
  });

  group('ReactiveEngine — batching', () {
    test('N writes inside a batch produce exactly one effect run', () {
      final MiniSignal<int> s1 = MiniSignal<int>(0);
      final MiniSignal<int> s2 = MiniSignal<int>(0);
      final List<int> seen = <int>[];
      final MiniEffect e = effect(() => seen.add(s1.get() + s2.get()));

      startBatch();
      s1.set(1);
      s2.set(2);
      s1.set(3);
      expect(e.runs, 1); // deferred / adiado
      endBatch();

      expect(e.runs, 2);
      expect(seen, <int>[
        0,
        5,
      ]); // only final consistent state / só o estado final
    });

    test('nested batches flush only when the outermost ends', () {
      final MiniSignal<int> s = MiniSignal<int>(0);
      final MiniEffect e = effect(() => s.get());

      startBatch();
      s.set(1);
      startBatch();
      s.set(2);
      endBatch();
      expect(e.runs, 1);
      endBatch();
      expect(e.runs, 2);
    });
  });

  group('ReactiveFlags', () {
    test('named masks match their composing bits', () {
      expect(ReactiveFlags.propagationState.raw, 60);
      expect(ReactiveFlags.anyRecursed.raw, 12);
      expect(ReactiveFlags.stale.raw, 48);
      expect(ReactiveFlags.recursedPending.raw, 40);
      expect(ReactiveFlags.mutableDirty.raw, 17);
      expect(ReactiveFlags.mutablePending.raw, 33);
      expect(ReactiveFlags.watchingOrChecking.raw, 6);
      expect(ReactiveFlags.mutableChecking.raw, 5);
    });

    test('hasAll / hasAny behave as documented', () {
      final ReactiveFlags f = ReactiveFlags.mutable | ReactiveFlags.dirty;
      expect(f.hasAll(ReactiveFlags.mutableDirty), isTrue);
      expect(f.hasAny(ReactiveFlags.pending), isFalse);
      expect(f.hasAny(ReactiveFlags.stale), isTrue);
    });
  });
}
