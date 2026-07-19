import '../model/observer_node.dart';
import '../model/observer_value_summary.dart';
import '../snapshot/observer_protocol_snapshot.dart';

/// Current-state metadata registry. It never stores user objects or raw values.
///
/// Registry de metadados do estado atual. Nunca armazena objetos do usuário
/// nem valores crus.
final class ProtocolRegistry {
  final Map<ObserverNodeId, ObserverNodeSnapshot> _nodes =
      <ObserverNodeId, ObserverNodeSnapshot>{};
  final Map<ObserverNodeId, Set<ObserverNodeId>> _dependencies =
      <ObserverNodeId, Set<ObserverNodeId>>{};
  final Map<ObserverNodeId, ProtocolScopeState> _scopes =
      <ObserverNodeId, ProtocolScopeState>{};

  /// Whether clearing this registry could orphan active protocol state.
  bool get hasState =>
      _nodes.isNotEmpty || _dependencies.isNotEmpty || _scopes.isNotEmpty;

  /// Clears every retained node, edge and scope.
  ///
  /// Limpa todos os nós, arestas e escopos retidos.
  void clear() {
    _nodes.clear();
    _dependencies.clear();
    _scopes.clear();
  }

  /// Registers or replaces active [node] metadata.
  ///
  /// Registra ou substitui os metadados do [node] ativo.
  void registerNode(ObserverNodeSnapshot node) => _nodes[node.objectId] = node;

  /// Replaces the safe summary of [objectId] when it is active.
  ///
  /// Substitui o resumo seguro de [objectId] quando ele está ativo.
  void updateNodeValue(ObserverNodeId objectId, ObserverValueSummary summary) {
    final ObserverNodeSnapshot? node = _nodes[objectId];
    if (node != null) {
      _nodes[objectId] = node.copyWith(valueSummary: summary);
    }
  }

  /// Removes [objectId] and every edge involving it.
  ///
  /// Remove [objectId] e todas as arestas relacionadas.
  void disposeNode(ObserverNodeId objectId) {
    _nodes.remove(objectId);
    _dependencies.remove(objectId);
    for (final Set<ObserverNodeId> ids in _dependencies.values) {
      ids.remove(objectId);
    }
  }

  /// Atomically replaces dependencies and returns their delta.
  ///
  /// Substitui atomicamente as dependências e retorna seu delta.
  ProtocolDependencyDelta replaceDependencies(
    ObserverNodeId trackerId,
    Set<ObserverNodeId> current,
  ) {
    final Set<ObserverNodeId> previous = Set<ObserverNodeId>.of(
      _dependencies[trackerId] ?? const <ObserverNodeId>{},
    );
    if (current.isEmpty) {
      _dependencies.remove(trackerId);
    } else {
      _dependencies[trackerId] = Set<ObserverNodeId>.of(current);
    }
    return ProtocolDependencyDelta(
      added: current.difference(previous),
      removed: previous.difference(current),
    );
  }

  /// Removes every dependency edge owned by [trackerId].
  ///
  /// Remove todas as arestas pertencentes a [trackerId].
  void disposeTracker(ObserverNodeId trackerId) {
    _dependencies.remove(trackerId);
  }

  /// Registers an active scope.
  ///
  /// Registra um escopo ativo.
  void registerScope(ObserverNodeId scopeId, String debugLabel) {
    _scopes[scopeId] = ProtocolScopeState(debugLabel);
  }

  /// Associates a resource with an active scope.
  ///
  /// Associa um recurso a um escopo ativo.
  void registerScopeResource(
    ObserverNodeId scopeId,
    ObserverNodeId resourceId,
    ObserverNodeKind resourceKind,
  ) {
    _scopes[scopeId]?.resources[resourceId] = resourceKind;
  }

  /// Removes an active scope.
  ///
  /// Remove um escopo ativo.
  void disposeScope(ObserverNodeId scopeId) => _scopes.remove(scopeId);

  /// Builds active node snapshots ordered by identity.
  ///
  /// Constrói snapshots dos nós ativos ordenados por identidade.
  List<ObserverNodeSnapshot> nodeSnapshots() {
    final List<ObserverNodeSnapshot> result = _nodes.values.toList();
    result.sort((a, b) => a.objectId.compareTo(b.objectId));
    return result;
  }

  /// Builds dependency snapshots ordered by tracker identity.
  ///
  /// Constrói snapshots de dependências ordenados pelo tracker.
  List<ObserverDependencySnapshot> dependencySnapshots() {
    final List<ObserverDependencySnapshot> result = _dependencies.entries
        .map(
          (entry) => ObserverDependencySnapshot(
            trackerId: entry.key,
            dependencyIds: entry.value,
          ),
        )
        .toList();
    result.sort((a, b) => a.trackerId.compareTo(b.trackerId));
    return result;
  }

  /// Builds scope snapshots with ordered resource identities.
  ///
  /// Constrói snapshots de escopo com recursos ordenados por identidade.
  List<ObserverScopeSnapshot> scopeSnapshots() {
    final List<ObserverScopeSnapshot> result = _scopes.entries.map((entry) {
      final List<ObserverScopeResourceSnapshot> resources = entry
          .value
          .resources
          .entries
          .map(
            (resource) => ObserverScopeResourceSnapshot(
              resourceId: resource.key,
              resourceKind: resource.value,
            ),
          )
          .toList();
      resources.sort((a, b) => a.resourceId.compareTo(b.resourceId));
      return ObserverScopeSnapshot(
        scopeId: entry.key,
        debugLabel: entry.value.debugLabel,
        resources: resources,
      );
    }).toList();
    result.sort((a, b) => a.scopeId.compareTo(b.scopeId));
    return result;
  }
}

/// Added/removed sets produced by one atomic dependency replacement.
///
/// Conjuntos adicionados/removidos por uma troca atômica de dependências.
final class ProtocolDependencyDelta {
  /// Creates a dependency delta.
  ///
  /// Cria um delta de dependências.
  ProtocolDependencyDelta({required this.added, required this.removed});

  /// Newly active dependency IDs.
  ///
  /// IDs de dependências recém-ativas.
  final Set<ObserverNodeId> added;

  /// Dependency IDs no longer active.
  ///
  /// IDs de dependências que deixaram de estar ativas.
  final Set<ObserverNodeId> removed;
}

/// Mutable scope metadata kept only inside [ProtocolRegistry].
///
/// Metadados mutáveis de escopo mantidos apenas no [ProtocolRegistry].
final class ProtocolScopeState {
  /// Creates internal scope state.
  ///
  /// Cria o estado interno do escopo.
  ProtocolScopeState(this.debugLabel);

  /// Human-readable label.
  ///
  /// Rótulo legível.
  final String debugLabel;

  /// Resource kinds keyed by stable identity.
  ///
  /// Tipos de recursos indexados por identidade estável.
  final Map<ObserverNodeId, ObserverNodeKind> resources =
      <ObserverNodeId, ObserverNodeKind>{};
}
