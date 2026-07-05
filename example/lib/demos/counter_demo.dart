import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

import '../controllers/counter_controller.dart';

/// Demo 1: a counter, a `Computed` derived total (double the count), and a
/// memoization log proving the `Computed` only recomputes when its
/// dependency actually changes.
///
/// The controller is created internally by default, but can be injected —
/// this is the "testable architecture" pattern this project recommends: see
/// `example/test/controller_unit_test.dart` and
/// `documentation/en/testing.md`.
///
/// Demo 1: um contador, um total derivado via `Computed` (o dobro do
/// contador), e um log de memoização provando que o `Computed` só
/// recalcula quando sua dependência realmente muda.
///
/// O controller é criado internamente por padrão, mas pode ser injetado —
/// este é o padrão de "arquitetura testável" recomendado por este projeto.
class CounterDemo extends StatefulWidget {
  /// Creates the counter + computed demo. Pass [controller] to inject one
  /// (e.g. from a test); otherwise a fresh [CounterController] is created
  /// and owned internally.
  ///
  /// Cria o demo de contador + computed. Passe [controller] para injetar um
  /// (ex.: a partir de um teste); caso contrário, um [CounterController]
  /// novo é criado e possuído internamente.
  const CounterDemo({super.key, this.controller});

  /// An optional externally-owned controller. When provided, this widget
  /// does NOT dispose it — the owner (typically a test) is responsible.
  ///
  /// Um controller opcional possuído externamente. Quando fornecido, este
  /// widget NÃO o descarta — quem o possui (tipicamente um teste) é
  /// responsável.
  final CounterController? controller;

  @override
  State<CounterDemo> createState() => _CounterDemoState();
}

class _CounterDemoState extends State<CounterDemo> {
  late final CounterController _controller;
  late final bool _ownsController;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
    // CounterController's constructor already forces + logs the first
    // compute, so there's nothing left to trigger here.
    _controller = widget.controller ?? CounterController();
  }

  @override
  void dispose() {
    if (_ownsController) {
      _controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Observer(() => Text('Count: ${_controller.count.value}')),
          Observer(
            () => Text('Doubled (Computed): ${_controller.doubled.value}'),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              ElevatedButton(
                onPressed: _controller.increment,
                child: const Text('Increment'),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _controller.reset,
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
                children: _controller.log.reversed
                    .map(Text.new)
                    .toList(growable: false),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
