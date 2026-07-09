import 'package:all_observer/all_observer.dart' as all;
import 'package:all_observer/core.dart' as core;
import 'package:all_observer/engine.dart' as engine;
import 'package:flutter_test/flutter_test.dart';

final class _SmokeEngine extends engine.ReactiveEngine {
  const _SmokeEngine();

  @override
  bool update(engine.ReactiveNode node) => true;

  @override
  void notify(engine.ReactiveNode node) {}

  @override
  void unwatched(engine.ReactiveNode node) {}
}

void main() {
  test('all_observer.dart exposes the Flutter-facing reactive API', () {
    final all.Observable<int> source = all.Observable<int>(1);
    final all.Computed<int> doubled = all.Computed<int>(() => source.value * 2);
    final all.RecordingInspector inspector = all.RecordingInspector();
    all.ObserverConfig.inspectors.add(inspector);

    expect(doubled.value, 2);
    source.value = 2;
    expect(doubled.value, 4);

    doubled.close();
    source.close();
    all.ObserverConfig.reset();
  });

  test('core.dart exposes a usable pure-Dart observable graph', () {
    final core.CoreObservable<int> source = core.CoreObservable<int>(2);
    final core.CoreComputed<int> tripled = core.CoreComputed<int>(
      () => source.value * 3,
    );
    final List<int> seen = <int>[];
    final core.ObservableSubscription subscription = tripled.listen(seen.add);

    expect(tripled.value, 6);
    source.value = 3;
    expect(seen, <int>[9]);

    subscription.cancel();
    tripled.close();
    source.close();
  });

  test('engine.dart exposes graph nodes and link lifecycle', () {
    const _SmokeEngine reactiveEngine = _SmokeEngine();
    final engine.ReactiveNode dependency = engine.ReactiveNode(
      flags: engine.ReactiveFlags.mutable,
    );
    final engine.ReactiveNode subscriber = engine.ReactiveNode(
      flags: engine.ReactiveFlags.watching,
    );

    reactiveEngine.link(dependency, subscriber, 1);

    expect(dependency.subs, isNotNull);
    expect(subscriber.deps, same(dependency.subs));
    expect(subscriber.deps!.dep, same(dependency));
    expect(subscriber.deps!.sub, same(subscriber));

    reactiveEngine.unlink(subscriber.deps!, subscriber);
    expect(dependency.subs, isNull);
    expect(subscriber.deps, isNull);
  });
}
