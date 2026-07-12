// A deliberately small signal/computed/effect implementation built on
// `package:all_observer/engine.dart`, used ONLY by the engine tests. It
// exercises every engine hook (update/notify/unwatched) and doubles as the
// design sketch for Fase 2 (rewiring CoreObservable/CoreComputed onto the
// engine). It is NOT public API.
//
// Uma implementação deliberadamente pequena de signal/computed/effect
// construída sobre `package:all_observer/engine.dart`, usada APENAS pelos
// testes do engine. Ela exercita todos os hooks do motor
// (update/notify/unwatched) e serve de rascunho de design para a Fase 2
// (religar CoreObservable/CoreComputed no motor). NÃO é API pública.
// ignore_for_file: public_member_api_docs
import 'package:all_observer/engine.dart';

int _cycle = 0;
int _batchDepth = 0;
ReactiveNode? _activeSub;
MiniEffect? _queuedHead;
MiniEffect? _queuedTail;

/// Engine singleton used by the fixture. / Singleton do motor usado pela
/// fixture.
final MiniEngine engine = MiniEngine();

/// Resets fixture globals between tests. / Zera os globais da fixture
/// entre testes.
void resetMiniPreset() {
  _batchDepth = 0;
  _activeSub = null;
  _queuedHead = _queuedTail = null;
  engine.unwatchedLog.clear();
}

class MiniSignal<T> extends ReactiveNode {
  MiniSignal(T initial)
    : _current = initial,
      _pending = initial,
      super(flags: ReactiveFlags.mutable);

  T _current;
  T _pending;

  void set(T newValue) {
    if (!identical(_pending, newValue)) {
      _pending = newValue;
      flags = ReactiveFlags.mutableDirty;
      final ReactiveLink? subs = this.subs;
      if (subs != null) {
        engine.propagate(subs);
        if (_batchDepth == 0) {
          flushEffects();
        }
      }
    }
  }

  T get() {
    if (flags.hasAny(ReactiveFlags.dirty)) {
      if (didUpdate()) {
        final ReactiveLink? subs = this.subs;
        if (subs != null) {
          engine.shallowPropagate(subs);
        }
      }
    }
    final ReactiveNode? sub = _activeSub;
    if (sub != null) {
      engine.link(this, sub, _cycle);
    }
    return _current;
  }

  bool didUpdate() {
    flags = ReactiveFlags.mutable;
    if (identical(_current, _pending)) {
      return false;
    }
    _current = _pending;
    return true;
  }
}

class MiniComputed<T> extends ReactiveNode {
  MiniComputed(this._compute, {bool Function(T a, T b)? equals})
    : _equals = equals,
      super(flags: ReactiveFlags.none);

  final T Function() _compute;
  final bool Function(T a, T b)? _equals;
  T? _value;

  /// Test instrumentation: how many times [_compute] actually ran.
  /// Instrumentação de teste: quantas vezes [_compute] realmente rodou.
  int recomputes = 0;

  T get() {
    final ReactiveFlags flags = this.flags;
    if (flags.hasAny(ReactiveFlags.dirty) ||
        (flags.hasAny(ReactiveFlags.pending) && _confirmStale())) {
      if (didUpdate()) {
        final ReactiveLink? subs = this.subs;
        if (subs != null) {
          engine.shallowPropagate(subs);
        }
      }
    } else if (flags == ReactiveFlags.none) {
      // First evaluation: track dependencies while computing.
      // Primeira avaliação: rastreia dependências enquanto computa.
      this.flags = ReactiveFlags.mutableChecking;
      final ReactiveNode? prevSub = _activeSub;
      _activeSub = this;
      try {
        recomputes++;
        _value = _compute();
      } finally {
        _activeSub = prevSub;
        this.flags = this.flags & ~ReactiveFlags.recursedCheck;
      }
    }
    final ReactiveNode? sub = _activeSub;
    if (sub != null) {
      engine.link(this, sub, _cycle);
    }
    return _value as T;
  }

  /// Pull-check: confirms whether `pending` really means stale, clearing
  /// the flag when it does not. / Checagem pull: confirma se `pending`
  /// significa mesmo obsoleto, limpando a flag quando não significa.
  bool _confirmStale() {
    if (engine.checkDirty(deps!, this)) {
      return true;
    }
    flags = flags & ~ReactiveFlags.pending;
    return false;
  }

  bool didUpdate() {
    depsTail = null; // re-tracking cursor / cursor de re-rastreamento
    flags = ReactiveFlags.mutableChecking;
    final ReactiveNode? prevSub = _activeSub;
    _activeSub = this;
    try {
      ++_cycle;
      recomputes++;
      final T? old = _value;
      final T next = _compute();
      _value = next;
      final bool Function(T a, T b)? eq = _equals;
      if (eq != null && old is T) {
        return !eq(old, next);
      }
      return !identical(old, next);
    } finally {
      _activeSub = prevSub;
      flags = flags & ~ReactiveFlags.recursedCheck;
      purgeDeps(this);
    }
  }
}

class MiniEffect extends ReactiveNode {
  MiniEffect(this._fn) : super(flags: ReactiveFlags.watching);

  final void Function() _fn;
  MiniEffect? nextEffect;

  /// Test instrumentation: how many times the body ran.
  /// Instrumentação de teste: quantas vezes o corpo rodou.
  int runs = 0;

  void _track() {
    final ReactiveNode? prevSub = _activeSub;
    _activeSub = this;
    try {
      ++_cycle;
      runs++;
      _fn();
    } finally {
      _activeSub = prevSub;
      flags = flags & ~ReactiveFlags.recursedCheck;
      purgeDeps(this);
    }
  }

  /// Stops the effect permanently. / Para o effect permanentemente.
  void stop() {
    flags = ReactiveFlags.none;
    disposeAllDepsInReverse(this);
    final ReactiveLink? subs = this.subs;
    if (subs != null) {
      engine.unlink(subs, subs.sub);
    }
  }
}

/// Creates and immediately runs an effect. / Cria e roda imediatamente um
/// effect.
MiniEffect effect(void Function() fn) {
  final MiniEffect e = MiniEffect(fn);
  e.flags = ReactiveFlags.watchingOrChecking;
  e._track();
  return e;
}

void _runQueued(MiniEffect e) {
  final ReactiveFlags flags = e.flags;
  if (flags.hasAny(ReactiveFlags.dirty) ||
      (flags.hasAny(ReactiveFlags.pending) && engine.checkDirty(e.deps!, e))) {
    e.depsTail = null;
    e.flags = ReactiveFlags.watchingOrChecking;
    e._track();
  } else if (e.deps != null) {
    // False alarm: pending but nothing actually changed upstream.
    // Alarme falso: pending mas nada mudou de fato acima.
    e.flags = ReactiveFlags.watching;
  }
}

/// Drains the effect queue. / Esvazia a fila de effects.
void flushEffects() {
  while (_queuedHead != null) {
    final MiniEffect e = _queuedHead!;
    _queuedHead = e.nextEffect;
    e.nextEffect = null;
    if (_queuedHead == null) {
      _queuedTail = null;
    }
    _runQueued(e);
  }
}

void startBatch() => ++_batchDepth;

void endBatch() {
  if (--_batchDepth == 0) {
    flushEffects();
  }
}

/// Unlinks every dependency after the re-tracking cursor (`depsTail`) —
/// i.e. the ones not re-confirmed by the latest run. / Desliga toda
/// dependência após o cursor de re-rastreamento (`depsTail`) — isto é, as
/// não reconfirmadas pela última execução.
void purgeDeps(ReactiveNode sub) {
  final ReactiveLink? tail = sub.depsTail;
  ReactiveLink? dep = tail != null ? tail.nextDep : sub.deps;
  while (dep != null) {
    dep = engine.unlink(dep, sub);
  }
}

/// Unlinks every dependency, newest first. / Desliga toda dependência, da
/// mais nova para a mais antiga.
void disposeAllDepsInReverse(ReactiveNode sub) {
  ReactiveLink? link = sub.depsTail;
  while (link != null) {
    final ReactiveLink? prev = link.prevDep;
    engine.unlink(link, sub);
    link = prev;
  }
}

/// Validates the intrusive dependency/subscriber lists reachable from
/// [nodes]. Test-only invariant checker for graph-mutation regressions.
void expectConsistentGraph(Iterable<ReactiveNode> nodes) {
  final Set<ReactiveLink> allDeps = <ReactiveLink>{};
  final Set<ReactiveLink> allSubs = <ReactiveLink>{};
  final Set<String> pairs = <String>{};

  for (final ReactiveNode node in nodes) {
    ReactiveLink? previous;
    ReactiveLink? current = node.deps;
    ReactiveLink? last;
    while (current != null) {
      if (!allDeps.add(current)) {
        throw StateError('duplicate dependency link in dependency lists');
      }
      if (!identical(current.sub, node)) {
        throw StateError('dependency link points at a different subscriber');
      }
      if (!identical(current.prevDep, previous)) {
        throw StateError('broken prevDep pointer');
      }
      if (current.nextDep != null &&
          !identical(current.nextDep!.prevDep, current)) {
        throw StateError('broken nextDep.prevDep pointer');
      }
      final String pair =
          '${identityHashCode(current.dep)}/${identityHashCode(current.sub)}';
      if (!pairs.add(pair)) {
        throw StateError('duplicate link for the same dep/sub pair');
      }
      last = current;
      previous = current;
      current = current.nextDep;
    }
    if (!identical(node.depsTail, last)) {
      throw StateError('depsTail is not the last dependency link');
    }

    previous = null;
    current = node.subs;
    last = null;
    while (current != null) {
      if (!allSubs.add(current)) {
        throw StateError('duplicate subscriber link in subscriber lists');
      }
      if (!identical(current.dep, node)) {
        throw StateError('subscriber link points at a different dependency');
      }
      if (!identical(current.prevSub, previous)) {
        throw StateError('broken prevSub pointer');
      }
      if (current.nextSub != null &&
          !identical(current.nextSub!.prevSub, current)) {
        throw StateError('broken nextSub.prevSub pointer');
      }
      last = current;
      previous = current;
      current = current.nextSub;
    }
    if (!identical(node.subsTail, last)) {
      throw StateError('subsTail is not the last subscriber link');
    }
  }

  for (final ReactiveLink link in allDeps) {
    if (!allSubs.contains(link)) {
      throw StateError('dependency link is missing from subscriber list');
    }
  }
  for (final ReactiveLink link in allSubs) {
    if (!allDeps.contains(link)) {
      throw StateError('subscriber link is missing from dependency list');
    }
  }
}

class MiniEngine extends ReactiveEngine {
  /// Test instrumentation: nodes that lost their last subscriber.
  /// Instrumentação de teste: nós que perderam seu último subscriber.
  final List<ReactiveNode> unwatchedLog = <ReactiveNode>[];

  @override
  bool update(ReactiveNode node) {
    return switch (node) {
      MiniComputed<Object?>() => node.didUpdate(),
      MiniSignal<Object?>() => node.didUpdate(),
      _ => false,
    };
  }

  @override
  void notify(ReactiveNode node) {
    final MiniEffect e = node as MiniEffect;
    e.flags = e.flags & ~ReactiveFlags.watching;
    if (_queuedTail == null) {
      _queuedHead = _queuedTail = e;
    } else {
      _queuedTail!.nextEffect = e;
      _queuedTail = e;
    }
  }

  @override
  void unwatched(ReactiveNode node) {
    unwatchedLog.add(node);
    switch (node) {
      case MiniComputed<Object?>():
        // Auto-release: nobody watches this computed anymore — drop its own
        // dependencies and force a fresh compute on the next read.
        // Auto-liberação: ninguém mais observa este computed — solta as
        // próprias dependências e força um cômputo novo na próxima leitura.
        if (node.depsTail != null) {
          node.flags = ReactiveFlags.mutableDirty;
          disposeAllDepsInReverse(node);
        }
      case MiniEffect():
        node.stop();
      case _:
        break; // signals stay alive / signals continuam vivos
    }
  }
}
