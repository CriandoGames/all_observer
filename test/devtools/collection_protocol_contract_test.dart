import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  tearDown(() {
    ObserverProtocol.reset();
    ObserverConfig.reset();
  });

  test(
    'collections stay reactive but are explicitly partial in protocol v1',
    () {
      ObserverProtocol.configure(
        const ObserverProtocolConfig(enabled: true, eventBufferSize: 100),
      );
      final ObservableList<int> list = ObservableList<int>(<int>[1], 'list');
      final ObservableMap<String, int> map = ObservableMap<String, int>(
        <String, int>{'a': 1},
        'map',
      );
      final ObservableSet<int> set = ObservableSet<int>(<int>{1}, 'set');
      final Computed<int> total = Computed<int>(
        () => list.length + map.length + set.length,
        name: 'collectionTotal',
      );
      var effectRuns = 0;
      final void Function() disposeEffect = effect(() {
        list.length;
        map.length;
        set.length;
        effectRuns++;
      }, name: 'collectionEffect');

      expect(total.value, 3);
      list.add(2);
      map['b'] = 2;
      set.add(2);
      expect(total.value, 6);
      expect(effectRuns, 4);

      final ObserverProtocolSnapshot snapshot = ObserverProtocol.snapshot();
      expect(
        snapshot.nodes.map((node) => node.kind),
        containsAll(<ObserverNodeKind>[
          ObserverNodeKind.computed,
          ObserverNodeKind.effect,
        ]),
      );
      expect(
        snapshot.nodes.any(
          (node) =>
              node.debugLabel.contains('ObservableList') ||
              node.debugLabel.contains('ObservableMap') ||
              node.debugLabel.contains('ObservableSet'),
        ),
        isFalse,
      );
      expect(
        snapshot.instrumentationCoverage,
        ObserverProtocolInstrumentationCoverage.partial,
      );
      expect(
        snapshot.coverageLimitations,
        contains(ObserverProtocolCoverageLimitation.reactiveCollections),
      );

      disposeEffect();
      total.close();
      list.close();
      map.close();
      set.close();
      expect(ObserverProtocol.snapshot().dependencies, isEmpty);
    },
  );
}
