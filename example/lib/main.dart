import 'package:flutter/material.dart';
import 'package:all_observer/all_observer.dart';

import 'demos/async_demo.dart';
import 'demos/batch_demo.dart';
import 'demos/counter_demo.dart';
import 'demos/interop_demo.dart';
import 'demos/search_demo.dart';

void main() {
  runApp(const ExampleApp());
}

/// Root app: a bottom-navigation shell over five demos (counter/computed,
/// debounced search, async, batch, interop), plus a runtime toggle for
/// debug logging shared by all of them.
///
/// App raiz: um shell com navegação inferior sobre cinco demos (contador/
/// computed, busca com debounce, assíncrono, batch, interop), mais um
/// alternador em tempo real para os logs de debug compartilhado por todos.
class ExampleApp extends StatelessWidget {
  /// Creates the example app.
  ///
  /// Cria o app de exemplo.
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ExampleHomePage());
  }
}

/// Home page: hosts the bottom navigation bar and swaps between demos.
///
/// Página inicial: hospeda a barra de navegação inferior e alterna entre
/// os demos.
class ExampleHomePage extends StatefulWidget {
  /// Creates the example home page.
  ///
  /// Cria a página inicial de exemplo.
  const ExampleHomePage({super.key});

  @override
  State<ExampleHomePage> createState() => _ExampleHomePageState();
}

class _ExampleHomePageState extends State<ExampleHomePage> {
  final ObservableInt _tabIndex = 0.obs;
  final ObservableBool _loggingEnabled = false.obs;
  late final Worker _loggingWorker;

  static const List<String> _titles = <String>[
    'Counter + Computed',
    'Debounced search',
    'Async',
    'Batch',
    'Interop',
  ];

  @override
  void initState() {
    super.initState();
    _loggingWorker = ever(_loggingEnabled, (bool value) {
      ObserverConfig.logging = value;
    });
  }

  @override
  void dispose() {
    _loggingWorker.dispose();
    _tabIndex.close();
    _loggingEnabled.close();
    super.dispose();
  }

  Widget _buildDemo(int index) {
    return switch (index) {
      0 => const CounterDemo(),
      1 => const SearchDemo(),
      2 => const AsyncDemo(),
      3 => const BatchDemo(),
      _ => const InteropDemo(),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Observer(() => Text(_titles[_tabIndex.value])),
        actions: <Widget>[
          ObserverValue<ObservableBool>(
            (data) => IconButton(
              tooltip: 'Logs de debug',
              icon: Icon(
                data.value ? Icons.bug_report : Icons.bug_report_outlined,
              ),
              onPressed: () => data.toggle(),
            ),
            _loggingEnabled,
          ),
        ],
      ),
      body: Observer(() => _buildDemo(_tabIndex.value)),
      bottomNavigationBar: Observer(
        () => NavigationBar(
          selectedIndex: _tabIndex.value,
          onDestinationSelected: _tabIndex.setValue,
          destinations: const <NavigationDestination>[
            NavigationDestination(icon: Icon(Icons.add), label: 'Counter'),
            NavigationDestination(icon: Icon(Icons.search), label: 'Search'),
            NavigationDestination(icon: Icon(Icons.cloud_sync), label: 'Async'),
            NavigationDestination(icon: Icon(Icons.layers), label: 'Batch'),
            NavigationDestination(
              icon: Icon(Icons.compare_arrows),
              label: 'Interop',
            ),
          ],
        ),
      ),
    );
  }
}
