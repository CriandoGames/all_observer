import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

/// Demo 5: the same `Observable<int>` driving an `Observer` widget and
/// Flutter's built-in `ValueListenableBuilder` side by side, since
/// `Observable<T>` implements `ValueListenable<T>` directly — no adapter
/// needed.
///
/// Demo 5: o mesmo `Observable<int>` controlando um widget `Observer` e o
/// `ValueListenableBuilder` nativo do Flutter lado a lado, já que
/// `Observable<T>` implementa `ValueListenable<T>` diretamente — sem
/// nenhum adaptador necessário.
class InteropDemo extends StatefulWidget {
  /// Creates the interop demo.
  ///
  /// Cria o demo de interoperabilidade.
  const InteropDemo({super.key});

  @override
  State<InteropDemo> createState() => _InteropDemoState();
}

class _InteropDemoState extends State<InteropDemo> {
  final ObservableInt _shared = 0.obs;

  @override
  void dispose() {
    _shared.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          const Text(
            'A single Observable<int> driving two different widgets:',
          ),
          const SizedBox(height: 16),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('all_observer Observer:'),
                  Observer(() => Text('${_shared.value}',
                      style: const TextStyle(fontSize: 24))),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const Text('Flutter ValueListenableBuilder:'),
                  ValueListenableBuilder<int>(
                    valueListenable: _shared, // Observable<int> works as-is
                    builder: (context, value, _) =>
                        Text('$value', style: const TextStyle(fontSize: 24)),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _shared.value++,
            child: const Text('Increment shared value'),
          ),
        ],
      ),
    );
  }
}
