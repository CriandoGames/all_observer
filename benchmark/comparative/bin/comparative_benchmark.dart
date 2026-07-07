// ignore_for_file: avoid_print
import 'package:alien_signals/alien_signals.dart' as alien;
import 'package:all_observer/core.dart';

/// Comparative benchmark: all_observer core vs alien_signals (v2.x).
///
/// Phase 0 of the "engine v2" evaluation (see
/// `documentation/analise-alien-signals.md` and ADR-0001 in
/// `ARCHITECTURE.md`): before adopting any of alien-signals' engine
/// techniques, measure where — and by how much — our current engine
/// actually loses. Ratios matter more than absolute numbers.
///
/// Only `package:all_observer/core.dart` is used (pure-Dart layer), so the
/// comparison is engine-vs-engine, without Flutter wrappers or logging.
///
/// Benchmark comparativo: core do all_observer vs alien_signals (v2.x).
///
/// Fase 0 da avaliação do "motor v2" (ver
/// `documentation/analise-alien-signals.md` e ADR-0001 no
/// `ARCHITECTURE.md`): antes de adotar qualquer técnica do motor do
/// alien-signals, medir onde — e por quanto — nosso motor atual perde de
/// fato. As razões importam mais que os números absolutos.
///
/// Apenas `package:all_observer/core.dart` é usado (camada Dart pura),
/// para a comparação ser motor-contra-motor, sem wrappers Flutter ou
/// logging.
///
/// Run with / Execute com:
///   cd benchmark/comparative
///   flutter pub get
///   dart run bin/comparative_benchmark.dart
void main() {
  print('Comparative benchmark: all_observer core vs alien_signals');
  print('==========================================================\n');

  _scenario(
    'S1  write+read hot path, no subscribers (1M iterations)',
    ours: () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      int sink = 0;
      return () {
        for (int i = 0; i < 1000000; i++) {
          a.value = i;
          sink = a.value;
        }
        return sink;
      };
    },
    theirs: () {
      final a = alien.signal(0);
      int sink = 0;
      return () {
        for (int i = 0; i < 1000000; i++) {
          a.set(i);
          sink = a();
        }
        return sink;
      };
    },
  );

  _scenario(
    'S2  diamond (a -> b,c -> d), 1 listener on d (100k writes)',
    ours: () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final CoreComputed<int> b = CoreComputed<int>(() => a.value + 1);
      final CoreComputed<int> c = CoreComputed<int>(() => a.value * 2);
      final CoreComputed<int> d = CoreComputed<int>(() => b.value + c.value);
      int sink = 0;
      d.addListener(() => sink = d.value);
      sink = d.value; // liven
      return () {
        for (int i = 0; i < 100000; i++) {
          a.value = i;
        }
        return sink;
      };
    },
    theirs: () {
      final a = alien.signal(0);
      final b = alien.computed((_) => a() + 1);
      final c = alien.computed((_) => a() * 2);
      final d = alien.computed((_) => b() + c());
      int sink = 0;
      alien.effect(() => sink = d());
      return () {
        for (int i = 0; i < 100000; i++) {
          a.set(i);
        }
        return sink;
      };
    },
  );

  _scenario(
    'S3  deep chain of 50 computeds, 1 listener at the end (10k writes)',
    ours: () {
      final CoreObservable<int> root = CoreObservable<int>(0);
      CoreComputed<int> prev = CoreComputed<int>(() => root.value + 1);
      for (int i = 1; i < 50; i++) {
        final CoreComputed<int> p = prev;
        prev = CoreComputed<int>(() => p.value + 1);
      }
      final CoreComputed<int> last = prev;
      int sink = 0;
      last.addListener(() => sink = last.value);
      sink = last.value;
      return () {
        for (int i = 0; i < 10000; i++) {
          root.value = i;
        }
        return sink;
      };
    },
    theirs: () {
      final root = alien.signal(0);
      alien.Computed<int> prev = alien.computed((_) => root() + 1);
      for (int i = 1; i < 50; i++) {
        final p = prev;
        prev = alien.computed((_) => p() + 1);
      }
      final last = prev;
      int sink = 0;
      alien.effect(() => sink = last());
      return () {
        for (int i = 0; i < 10000; i++) {
          root.set(i);
        }
        return sink;
      };
    },
  );

  _scenario(
    'S4  fan-out: 1 source -> 500 computeds, each with a listener (1k writes)',
    ours: () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      int sink = 0;
      for (int i = 0; i < 500; i++) {
        final CoreComputed<int> c = CoreComputed<int>(() => a.value + i);
        c.addListener(() => sink = c.value);
        sink = c.value;
      }
      return () {
        for (int i = 0; i < 1000; i++) {
          a.value = i;
        }
        return sink;
      };
    },
    theirs: () {
      final a = alien.signal(0);
      int sink = 0;
      for (int i = 0; i < 500; i++) {
        final c = alien.computed((_) => a() + i);
        alien.effect(() => sink = c());
      }
      return () {
        for (int i = 0; i < 1000; i++) {
          a.set(i);
        }
        return sink;
      };
    },
  );

  _scenario(
    'S5  1000 UNREAD computeds, no listeners (10k writes) — lazy vs eager',
    ours: () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final List<CoreComputed<int>> cs = <CoreComputed<int>>[
        for (int i = 0; i < 1000; i++) CoreComputed<int>(() => a.value + i),
      ];
      // Liven once (first read) so dependencies exist, then never read again.
      // Ativa uma vez (primeira leitura) para as dependências existirem, e
      // nunca mais lê.
      int sink = 0;
      for (final CoreComputed<int> c in cs) {
        sink = c.value;
      }
      return () {
        for (int i = 0; i < 10000; i++) {
          a.value = i;
        }
        return sink;
      };
    },
    theirs: () {
      final a = alien.signal(0);
      final cs = <alien.Computed<int>>[
        for (int i = 0; i < 1000; i++) alien.computed((_) => a() + i),
      ];
      int sink = 0;
      for (final c in cs) {
        sink = c();
      }
      return () {
        for (int i = 0; i < 10000; i++) {
          a.set(i);
        }
        return sink;
      };
    },
  );

  _scenario(
    'S6  batched writes: 10 writes/batch x 10k batches, diamond + listener',
    ours: () {
      final CoreObservable<int> a = CoreObservable<int>(0);
      final CoreComputed<int> b = CoreComputed<int>(() => a.value + 1);
      final CoreComputed<int> c = CoreComputed<int>(() => a.value * 2);
      final CoreComputed<int> d = CoreComputed<int>(() => b.value + c.value);
      int sink = 0;
      d.addListener(() => sink = d.value);
      sink = d.value;
      return () {
        for (int i = 0; i < 10000; i++) {
          BatchScope.run(() {
            for (int j = 0; j < 10; j++) {
              a.value = i * 10 + j;
            }
          });
        }
        return sink;
      };
    },
    theirs: () {
      final a = alien.signal(0);
      final b = alien.computed((_) => a() + 1);
      final c = alien.computed((_) => a() * 2);
      final d = alien.computed((_) => b() + c());
      int sink = 0;
      alien.effect(() => sink = d());
      return () {
        for (int i = 0; i < 10000; i++) {
          alien.startBatch();
          for (int j = 0; j < 10; j++) {
            a.set(i * 10 + j);
          }
          alien.endBatch();
        }
        return sink;
      };
    },
  );

  print('\nDone. Copy the table above into benchmark/RESULTS.md.');
  print('Concluído. Copie a tabela acima para benchmark/RESULTS.md.');
}

/// Runs one scenario for both libraries: 1 warmup run + [kRuns] timed runs,
/// reporting the best (minimum) time of each side and the ratio.
///
/// Executa um cenário para as duas bibliotecas: 1 rodada de aquecimento +
/// [kRuns] rodadas medidas, reportando o melhor (mínimo) tempo de cada lado
/// e a razão.
void _scenario(
  String name, {
  required int Function() Function() ours,
  required int Function() Function() theirs,
}) {
  const int kRuns = 5;
  final int oursUs = _best(kRuns, ours);
  final int theirsUs = _best(kRuns, theirs);
  final String ratio = (oursUs / theirsUs).toStringAsFixed(2);
  print(name);
  print('  all_observer : ${_fmt(oursUs)} us');
  print('  alien_signals: ${_fmt(theirsUs)} us');
  print('  ratio (ours/theirs): ${ratio}x\n');
}

int _best(int runs, int Function() Function() setup) {
  int best = 1 << 62;
  // Fresh graph per run so listener/link state never accumulates across runs.
  // Grafo novo por rodada para o estado de listeners/links não acumular.
  for (int r = 0; r <= runs; r++) {
    final int Function() body = setup();
    final Stopwatch w = Stopwatch()..start();
    final int sink = body();
    w.stop();
    if (sink == -1) print('impossible'); // keep `sink` alive / evita DCE
    if (r > 0 && w.elapsedMicroseconds < best) best = w.elapsedMicroseconds;
  }
  return best;
}

String _fmt(int us) => us.toString().replaceAllMapped(
  RegExp(r'(\d)(?=(\d{3})+$)'),
  (Match m) => '${m[1]},',
);
