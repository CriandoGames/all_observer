// Benchmark output is intentionally written as a Markdown table.
// A saída do benchmark é intencionalmente uma tabela Markdown.
// ignore_for_file: avoid_print

import 'package:all_observer/core.dart';

final class _EmptyProtocolInspector extends ObserverProtocolInspector {
  @override
  void onProtocolEvent(ObserverProtocolEvent event) {}
}

final class _Result {
  const _Result(this.name, this.iterations, this.microsPerOperation);

  final String name;
  final int iterations;
  final double microsPerOperation;
}

void main() {
  const int updates = 200000;
  final List<_Result> results = <_Result>[
    _updates('disabled', updates, const ObserverProtocolConfig()),
    _updates(
      'enabled, no consumer',
      updates,
      const ObserverProtocolConfig(enabled: true),
    ),
    _updates(
      'one empty consumer',
      updates,
      const ObserverProtocolConfig(enabled: true),
      consumers: 1,
    ),
    _updates(
      'five empty consumers',
      updates,
      const ObserverProtocolConfig(enabled: true),
      consumers: 5,
    ),
    _updates(
      'registry, buffer zero',
      updates,
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
    ),
    _updates(
      'registry disabled, buffer zero',
      updates,
      const ObserverProtocolConfig(
        enabled: true,
        registryEnabled: false,
        eventBufferSize: 0,
      ),
    ),
    _updates(
      'registry + buffer 1',
      updates,
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 1),
    ),
    _updates(
      'registry + buffer 1000',
      updates,
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 1000),
    ),
    _updates(
      'registry + buffer 100000',
      updates,
      const ObserverProtocolConfig(enabled: true, eventBufferSize: 100000),
    ),
    _updates(
      'safe value capture',
      updates,
      const ObserverProtocolConfig(
        enabled: true,
        captureValues: true,
        eventBufferSize: 1000,
      ),
    ),
    _updates(
      'stack capture',
      20000,
      const ObserverProtocolConfig(
        enabled: true,
        captureStackTraces: true,
        eventBufferSize: 1000,
      ),
    ),
    _identity(1000000),
    _snapshot(nodes: 1000, snapshots: 1000),
    _computedChain(updates: 100000),
    _dependencyReplacement(dependencies: 100, runs: 10000),
    _dependencyReplacement(dependencies: 1000, runs: 1000),
    _conditionalDependencies(runs: 100000),
    _scopeDisposal(resources: 1000, runs: 200),
    _nodeChurn(nodes: 100000),
  ];

  final double disabled = results.first.microsPerOperation;
  print('| Scenario | Iterations | µs/op | vs disabled updates |');
  print('| --- | ---: | ---: | ---: |');
  for (final _Result result in results) {
    final String ratio = result.name == 'disabled'
        ? '1.00x'
        : '${(result.microsPerOperation / disabled).toStringAsFixed(2)}x';
    print(
      '| ${result.name} | ${result.iterations} | '
      '${result.microsPerOperation.toStringAsFixed(4)} | $ratio |',
    );
  }
}

_Result _nodeChurn({required int nodes}) {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
  );
  final Stopwatch watch = Stopwatch()..start();
  for (int index = 0; index < nodes; index++) {
    CoreObservable<int>(index).close();
  }
  watch.stop();
  return _Result(
    'node create/dispose churn',
    nodes,
    watch.elapsedMicroseconds / nodes,
  );
}

_Result _updates(
  String name,
  int iterations,
  ObserverProtocolConfig config, {
  int consumers = 0,
}) {
  ObserverConfig.reset();
  ObserverProtocol.configure(config);
  ObserverConfig.inspectors.addAll(
    List<ObserverInspector>.generate(
      consumers,
      (_) => _EmptyProtocolInspector(),
    ),
  );
  final CoreObservable<int> value = CoreObservable<int>(-10000);
  for (int index = -9999; index < 0; index++) {
    value.value = index;
  }
  final Stopwatch watch = Stopwatch()..start();
  for (int index = 0; index < iterations; index++) {
    value.value = index;
  }
  watch.stop();
  value.close();
  return _Result(name, iterations, watch.elapsedMicroseconds / iterations);
}

_Result _identity(int iterations) {
  final Stopwatch watch = Stopwatch()..start();
  for (int index = 0; index < iterations; index++) {
    ObserverProtocol.allocateNodeId();
  }
  watch.stop();
  return _Result(
    'ID generation',
    iterations,
    watch.elapsedMicroseconds / iterations,
  );
}

_Result _snapshot({required int nodes, required int snapshots}) {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
  );
  final List<CoreObservable<int>> values = List<CoreObservable<int>>.generate(
    nodes,
    (int index) => CoreObservable<int>(index),
  );
  final Stopwatch watch = Stopwatch()..start();
  for (int index = 0; index < snapshots; index++) {
    ObserverProtocol.snapshot();
  }
  watch.stop();
  for (final CoreObservable<int> value in values) {
    value.close();
  }
  return _Result(
    'snapshot of $nodes nodes',
    snapshots,
    watch.elapsedMicroseconds / snapshots,
  );
}

_Result _dependencyReplacement({required int dependencies, required int runs}) {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
  );
  final List<CoreObservable<int>> values = List<CoreObservable<int>>.generate(
    dependencies,
    (int index) => CoreObservable<int>(index),
  );
  final ObserverProtocolTracker tracker = ObserverProtocol.tracker(
    trackerId: ObserverProtocol.allocateNodeId(),
    kind: ObserverNodeKind.effect,
  );
  final Stopwatch watch = Stopwatch()..start();
  for (int run = 0; run < runs; run++) {
    final TrackingContext context = TrackingContext(
      () {},
      subscribes: false,
      protocolTracker: tracker,
    );
    DependencyTracker.track(context, () {
      for (final CoreObservable<int> value in values) {
        value.value;
      }
    });
  }
  watch.stop();
  for (final CoreObservable<int> value in values) {
    value.close();
  }
  return _Result(
    'dependency set of $dependencies',
    runs,
    watch.elapsedMicroseconds / runs,
  );
}

_Result _computedChain({required int updates}) {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
  );
  final CoreObservable<int> source = CoreObservable<int>(0);
  final CoreComputed<int> first = CoreComputed<int>(() => source.value + 1);
  final CoreComputed<int> second = CoreComputed<int>(() => first.value + 1);
  final CoreComputed<int> third = CoreComputed<int>(() => second.value + 1);
  third.value;
  final Stopwatch watch = Stopwatch()..start();
  for (int index = 1; index <= updates; index++) {
    source.value = index;
    third.value;
  }
  watch.stop();
  third.close();
  second.close();
  first.close();
  source.close();
  return _Result(
    'three-computed chain',
    updates,
    watch.elapsedMicroseconds / updates,
  );
}

_Result _conditionalDependencies({required int runs}) {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
  );
  final CoreObservable<bool> enabled = CoreObservable<bool>(true);
  final CoreObservable<int> active = CoreObservable<int>(1);
  final CoreObservable<int> inactive = CoreObservable<int>(2);
  final ObserverProtocolTracker tracker = ObserverProtocol.tracker(
    trackerId: ObserverProtocol.allocateNodeId(),
    kind: ObserverNodeKind.effect,
  );
  final Stopwatch watch = Stopwatch()..start();
  for (int run = 0; run < runs; run++) {
    final TrackingContext context = TrackingContext(
      () {},
      subscribes: false,
      protocolTracker: tracker,
    );
    DependencyTracker.track(context, () {
      enabled.value ? active.value : inactive.value;
    });
    enabled.value = !enabled.value;
  }
  watch.stop();
  inactive.close();
  active.close();
  enabled.close();
  return _Result(
    'conditional dependency switch',
    runs,
    watch.elapsedMicroseconds / runs,
  );
}

_Result _scopeDisposal({required int resources, required int runs}) {
  ObserverProtocol.configure(
    const ObserverProtocolConfig(enabled: true, eventBufferSize: 0),
  );
  final Stopwatch watch = Stopwatch()..start();
  for (int run = 0; run < runs; run++) {
    final ReactiveScope scope = ReactiveScope();
    for (int index = 0; index < resources; index++) {
      scope.add(() {});
    }
    scope.dispose();
  }
  watch.stop();
  return _Result(
    'scope disposal of $resources',
    runs,
    watch.elapsedMicroseconds / runs,
  );
}
