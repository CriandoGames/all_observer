/// Stable, process-local identity assigned by a monotonic counter.
///
/// Identidade estável no processo, atribuída por contador monotônico.
final class ObserverNodeId implements Comparable<ObserverNodeId> {
  /// Creates an ID from its numeric representation.
  ///
  /// Cria um ID a partir de sua representação numérica.
  const ObserverNodeId(this.value);

  /// Monotonic numeric representation used for cheap comparison/storage.
  ///
  /// Representação monotônica usada para comparação/armazenamento baratos.
  final int value;

  @override
  int compareTo(ObserverNodeId other) => value.compareTo(other.value);

  @override
  bool operator ==(Object other) =>
      other is ObserverNodeId && other.value == value;

  @override
  int get hashCode => value.hashCode;

  @override
  String toString() => 'node-$value';
}

/// Logical roles currently instrumented by the protocol.
///
/// Papéis lógicos atualmente instrumentados pelo protocolo.
enum ObserverNodeKind {
  /// Mutable scalar observable.
  /// Observável escalar mutável.
  observable,

  /// Derived computed value.
  /// Valor derivado computado.
  computed,

  /// Flutter Observer tracker.
  /// Tracker do Observer Flutter.
  observer,

  /// Flutter `watch(context)` tracker.
  /// Tracker do `watch(context)` Flutter.
  watch,

  /// Standalone reactive effect.
  /// Effect reativo autônomo.
  effect,

  /// Reactive resource scope.
  /// Escopo de recursos reativos.
  scope,

  /// Single-observable worker.
  /// Worker de um único observável.
  worker,

  /// Manually registered disposable resource.
  /// Recurso descartável registrado manualmente.
  subscription,
}
