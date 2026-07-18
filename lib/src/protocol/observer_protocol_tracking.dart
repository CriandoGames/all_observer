import 'model/observer_node.dart';

/// Internal stable tracker descriptor shared with the dependency tracker.
///
/// Consumers do not construct this type; reactive owners obtain one from
/// `ObserverProtocol.tracker`.
///
/// Descritor interno e estável compartilhado com o rastreador de
/// dependências. Consumidores não constroem este tipo; os donos reativos o
/// obtêm por `ObserverProtocol.tracker`.
final class ObserverProtocolTracker {
  /// Creates a tracker descriptor for [trackerId] and [kind].
  ///
  /// Cria um descritor para [trackerId] e [kind].
  ObserverProtocolTracker({required this.trackerId, required this.kind});

  /// Stable identity of the tracked owner.
  ///
  /// Identidade estável do dono rastreado.
  final ObserverNodeId trackerId;

  /// Logical role of the tracked owner.
  ///
  /// Papel lógico do dono rastreado.
  final ObserverNodeKind kind;
}

/// Internal token pairing a tracker start with its guaranteed finish.
///
/// Token interno que pareia o início do tracker com seu fim garantido.
final class ObserverProtocolRun {
  /// Creates a run token.
  ///
  /// Cria um token de execução.
  const ObserverProtocolRun({
    required this.tracker,
    required this.runId,
    required this.startedAtMicros,
  });

  /// Tracker executing this run.
  ///
  /// Tracker que executa esta passagem.
  final ObserverProtocolTracker tracker;

  /// Session-unique execution identity.
  ///
  /// Identidade de execução única na sessão.
  final String runId;

  /// Monotonic start used only to calculate elapsed duration.
  ///
  /// Início monotônico usado apenas para calcular a duração.
  final int startedAtMicros;
}
