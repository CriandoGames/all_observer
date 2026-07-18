import '../model/observer_node.dart';
import '../model/observer_value_summary.dart';

/// Immutable active-node entry in a protocol snapshot.
/// Entrada imutável de nó ativo em um snapshot.
final class ObserverNodeSnapshot {
  /// Creates a node snapshot entry.
  /// Cria uma entrada de snapshot de nó.
  const ObserverNodeSnapshot({
    required this.objectId,
    required this.kind,
    required this.debugLabel,
    required this.debugType,
    required this.createdAtMicros,
    this.valueSummary,
  });

  /// Stable node identity.
  /// Identidade estável do nó.
  final ObserverNodeId objectId;

  /// Logical node role.
  /// Papel lógico do nó.
  final ObserverNodeKind kind;

  /// Human-readable label, never used as identity.
  /// Rótulo legível, nunca usado como identidade.
  final String debugLabel;

  /// Runtime type used for diagnostics.
  /// Tipo em runtime usado para diagnóstico.
  final String debugType;

  /// Creation wall-clock time in microseconds since epoch.
  /// Criação em relógio de parede, em microssegundos desde epoch.
  final int createdAtMicros;

  /// Latest safe value summary, when applicable.
  /// Resumo seguro mais recente, quando aplicável.
  final ObserverValueSummary? valueSummary;

  /// Returns a copy with a replaced value summary.
  /// Retorna uma cópia substituindo o resumo de valor.
  ObserverNodeSnapshot copyWith({ObserverValueSummary? valueSummary}) =>
      ObserverNodeSnapshot(
        objectId: objectId,
        kind: kind,
        debugLabel: debugLabel,
        debugType: debugType,
        createdAtMicros: createdAtMicros,
        valueSummary: valueSummary,
      );
}

/// Immutable active dependency set for one tracker.
/// Conjunto imutável de dependências ativas de um tracker.
final class ObserverDependencySnapshot {
  /// Creates a dependency snapshot entry.
  /// Cria uma entrada de snapshot de dependências.
  ObserverDependencySnapshot({
    required this.trackerId,
    required Set<ObserverNodeId> dependencyIds,
  }) : dependencyIds = Set<ObserverNodeId>.unmodifiable(dependencyIds);

  /// Stable tracker identity.
  /// Identidade estável do tracker.
  final ObserverNodeId trackerId;

  /// Deduplicated current dependency identities.
  /// Identidades atuais e deduplicadas das dependências.
  final Set<ObserverNodeId> dependencyIds;
}

/// Immutable resource entry owned by a scope.
/// Entrada imutável de recurso pertencente a um escopo.
final class ObserverScopeResourceSnapshot {
  /// Creates a scope-resource snapshot entry.
  /// Cria uma entrada de recurso de escopo.
  const ObserverScopeResourceSnapshot({
    required this.resourceId,
    required this.resourceKind,
  });

  /// Stable resource identity.
  /// Identidade estável do recurso.
  final ObserverNodeId resourceId;

  /// Logical resource role.
  /// Papel lógico do recurso.
  final ObserverNodeKind resourceKind;
}

/// Immutable active scope and its registered resources.
/// Escopo ativo imutável e seus recursos registrados.
final class ObserverScopeSnapshot {
  /// Creates a scope snapshot entry with an immutable resource list.
  /// Cria um snapshot de escopo com lista imutável de recursos.
  ObserverScopeSnapshot({
    required this.scopeId,
    required this.debugLabel,
    required List<ObserverScopeResourceSnapshot> resources,
  }) : resources = List<ObserverScopeResourceSnapshot>.unmodifiable(resources);

  /// Stable scope identity.
  /// Identidade estável do escopo.
  final ObserverNodeId scopeId;

  /// Human-readable scope label.
  /// Rótulo legível do escopo.
  final String debugLabel;

  /// Resources currently registered in this scope.
  /// Recursos atualmente registrados neste escopo.
  final List<ObserverScopeResourceSnapshot> resources;
}

/// Consistent immutable view of protocol state at [lastSequenceNumber].
/// Visão consistente e imutável no [lastSequenceNumber].
final class ObserverProtocolSnapshot {
  /// Creates a complete immutable protocol snapshot.
  /// Cria um snapshot completo e imutável do protocolo.
  ObserverProtocolSnapshot({
    required this.protocolVersion,
    required this.sessionId,
    required this.generatedAtMicros,
    required this.lastSequenceNumber,
    required List<ObserverNodeSnapshot> nodes,
    required List<ObserverDependencySnapshot> dependencies,
    required List<ObserverScopeSnapshot> scopes,
    required this.droppedEventCount,
    required this.firstAvailableSequence,
    required this.lastAvailableSequence,
  }) : nodes = List<ObserverNodeSnapshot>.unmodifiable(nodes),
       dependencies = List<ObserverDependencySnapshot>.unmodifiable(
         dependencies,
       ),
       scopes = List<ObserverScopeSnapshot>.unmodifiable(scopes);

  /// Protocol schema version.
  /// Versão do schema do protocolo.
  final int protocolVersion;

  /// Session represented by this snapshot.
  /// Sessão representada por este snapshot.
  final String sessionId;

  /// Snapshot wall-clock time in microseconds since epoch.
  /// Horário do snapshot em microssegundos desde epoch.
  final int generatedAtMicros;

  /// Last protocol event included in this state.
  /// Último evento incluído neste estado.
  final int lastSequenceNumber;

  /// Active nodes ordered by identity.
  /// Nós ativos ordenados por identidade.
  final List<ObserverNodeSnapshot> nodes;

  /// Active dependency sets ordered by tracker identity.
  /// Dependências ativas ordenadas pelo tracker.
  final List<ObserverDependencySnapshot> dependencies;

  /// Active scopes ordered by identity.
  /// Escopos ativos ordenados por identidade.
  final List<ObserverScopeSnapshot> scopes;

  /// Total events evicted or rejected by the bounded buffer.
  /// Total de eventos removidos ou rejeitados pelo buffer.
  final int droppedEventCount;

  /// Oldest sequence retained by the buffer, or `null` when empty.
  /// Sequência retida mais antiga, ou `null` quando vazio.
  final int? firstAvailableSequence;

  /// Newest sequence retained by the buffer, or `null` when empty.
  /// Sequência retida mais recente, ou `null` quando vazio.
  final int? lastAvailableSequence;
}
