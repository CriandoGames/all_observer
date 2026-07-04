import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

void main() {
  runApp(const ExampleApp());
}

/// Demonstrates: a counter, a reactive list, a worker, and a runtime
/// toggle for debug logging.
///
/// Demonstra: um contador, uma lista reativa, um worker, e um alternador
/// em tempo real para os logs de debug.
class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ExampleHomePage());
  }
}

/// Home page wiring together the demo widgets.
///
/// Página inicial que conecta os widgets de demonstração.
class ExampleHomePage extends StatefulWidget {
  /// Creates the example home page.
  ///
  /// Cria a página inicial de exemplo.
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final ObservableInt _count = 0.obs;
  final ObservableList<String> _items = <String>[].obs;
  final ObservableBool _loggingEnabled = false.obs;
  late final Worker _everWorker;

  @override
  void initState() {
    super.initState();
    _everWorker = ever(_count, (int value) {
      if (value != 0 && value % 5 == 0) {
        _items.add('Marco: $value');
      }
    });
    _loggingEnabled.listen((_) {
      ObserverConfig.logging = _loggingEnabled.value;
    });
  }

  @override
  void dispose() {
    _everWorker.dispose();
    _count.close();
    _items.close();
    _loggingEnabled.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('all_observer example')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Observer(() => Text('Contador: ${_count.value}')),
            ElevatedButton(
              onPressed: () => _count.value++,
              child: const Text('Incrementar'),
            ),
            const SizedBox(height: 16),
            const Text('Marcos (múltiplos de 5):'),
            Expanded(
              child: Observer(
                () => ListView(
                  children: _items.map(Text.new).toList(growable: false),
                ),
              ),
            ),
            ObserverValue<ObservableBool>(
              (data) => SwitchListTile(
                title: const Text('Logs de debug'),
                value: data.value,
                onChanged: (bool value) => data.value = value,
              ),
              _loggingEnabled,
            ),
          ],
        ),
      ),
    );
  }
}
