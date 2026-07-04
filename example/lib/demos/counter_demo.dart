import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

/// Demo 1: a counter, a `Computed` derived total (double the count), and a
/// memoization log proving the `Computed` only recomputes when its
/// dependency actually changes.
///
/// Demo 1: um contador, um total derivado via `Computed` (o dobro do
/// contador), e um log de memoização provando que o `Computed` só
/// recalcula quando sua dependência realmente muda.
class CounterDemo extends StatefulWidget {
  /// Creates the counter + computed demo.
  ///
  /// Cria o demo de contador + computed.
  const CounterDemo({super.key});

  @override
  State<CounterDemo> createState() => _CounterDemoState();
}

class _CounterDemoState extends State<CounterDemo> {
  final ObservableInt _count = 0.obs;
  late final Computed<int> _doubled;
  final ObservableList<String> _log = <String>[].obs;
  int _computeRuns = 0;

  @override
  void initState() {
    super.initState();
    _doubled = Computed<int>(() {
      _computeRuns++;
      final int value = _count.value * 2;
      _log.add('compute #$_computeRuns -> $value');
      return value;
    });
    // Force the first compute so the log shows it immediately.
    _doubled.value;
  }

  @override
  void dispose() {
    _count.close();
    _doubled.close();
    _log.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Observer(() => Text('Count: ${_count.value}')),
          Observer(() => Text('Doubled (Computed): ${_doubled.value}')),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: () => _count.value++,
                child: const Text('Increment'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: () => _count.setValue(0),
                child: const Text('Reset'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Memoization log (each entry is one real recompute):',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          Expanded(
            child: Observer(
              () => ListView(
                children: _log.reversed.map(Text.new).toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
