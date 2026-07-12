import 'package:all_observer/core.dart';
import 'package:all_observer/engine.dart';

final class _SmokeEngine extends ReactiveEngine {
  const _SmokeEngine();

  @override
  bool update(ReactiveNode node) => false;

  @override
  void notify(ReactiveNode node) {}

  @override
  void unwatched(ReactiveNode node) {}
}

void main() {
  const ReactiveEngine engine = _SmokeEngine();
  final ReactiveNode dep = ReactiveNode(flags: ReactiveFlags.mutable);
  final ReactiveNode sub = ReactiveNode(flags: ReactiveFlags.watching);
  engine.link(dep, sub, 1);

  final CoreObservable<int> source = CoreObservable<int>(1);
  final CoreComputed<int> doubled = CoreComputed<int>(() => source.value * 2);

  if (doubled.value != 2 || dep.subs == null || sub.deps == null) {
    throw StateError('dart2js smoke failed');
  }
}
