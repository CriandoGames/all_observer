/// Base for every event [ObserverInspector] receives: carries the label of
/// the observable/Computed/Effect/Observer involved and the moment it
/// occurred.
///
/// Base para todo evento que [ObserverInspector] recebe: carrega o rótulo
/// do observável/Computed/Effect/Observer envolvido e o momento em que
/// ocorreu.
class ObservableEvent {
  /// Creates an event for [label] at the current time, optionally carrying
  /// a debug [stackTrace] (only populated when
  /// `ObserverConfig.captureStackTraces` is `true`, since capturing one is
  /// not free).
  ///
  /// Cria um evento para [label] no instante atual, opcionalmente carregando
  /// um [stackTrace] de debug (só populado quando
  /// `ObserverConfig.captureStackTraces` for `true`, já que capturar um não
  /// é gratuito).
  ObservableEvent(this.label, {this.stackTrace}) : timestamp = DateTime.now();

  /// Debug label of the observable/Computed/Effect/Observer this event is
  /// about.
  ///
  /// Rótulo de debug do observável/Computed/Effect/Observer ao qual este
  /// evento se refere.
  final String label;

  /// When this event occurred.
  ///
  /// Quando este evento ocorreu.
  final DateTime timestamp;

  /// Stack trace captured at the point of the event, if
  /// `ObserverConfig.captureStackTraces` was enabled. `null` otherwise
  /// (the default, since capturing a trace on every event is not free).
  ///
  /// Stack trace capturado no ponto do evento, se
  /// `ObserverConfig.captureStackTraces` estava habilitado. `null` caso
  /// contrário (o padrão, já que capturar um trace a cada evento não é
  /// gratuito).
  final StackTrace? stackTrace;
}

/// Emitted when an [Observable]/`Computed` is created.
///
/// Emitido quando um [Observable]/`Computed` é criado.
class ObservableCreateEvent extends ObservableEvent {
  /// Creates a create-event for [label] holding [initialValue].
  ///
  /// Cria um evento de criação para [label] contendo [initialValue].
  ObservableCreateEvent(super.label, this.initialValue, {super.stackTrace});

  /// The value the observable was created with.
  ///
  /// O valor com o qual o observável foi criado.
  final Object? initialValue;
}

/// Emitted when an [Observable]/`Computed` notifies a value change.
///
/// Emitido quando um [Observable]/`Computed` notifica uma mudança de valor.
class ObservableUpdateEvent extends ObservableEvent {
  /// Creates an update-event for [label] going from [oldValue] to
  /// [newValue].
  ///
  /// Cria um evento de atualização para [label] indo de [oldValue] para
  /// [newValue].
  ObservableUpdateEvent(
    super.label,
    this.oldValue,
    this.newValue, {
    super.stackTrace,
  });

  /// The value immediately before this change.
  ///
  /// O valor imediatamente antes desta mudança.
  final Object? oldValue;

  /// The value immediately after this change.
  ///
  /// O valor imediatamente depois desta mudança.
  final Object? newValue;
}

/// Emitted when an [Observable]/`Computed` is disposed.
///
/// Emitido quando um [Observable]/`Computed` é descartado.
class ObservableDisposeEvent extends ObservableEvent {
  /// Creates a dispose-event for [label], noting how many [listenerCount]
  /// listeners were removed.
  ///
  /// Cria um evento de descarte para [label], anotando quantos
  /// [listenerCount] listeners foram removidos.
  ObservableDisposeEvent(super.label, this.listenerCount, {super.stackTrace});

  /// Number of listeners that were attached at the moment of disposal.
  ///
  /// Número de listeners que estavam anexados no momento do descarte.
  final int listenerCount;
}

/// Emitted when an [Observer]/`Computed`/`Effect` (identified by
/// [trackerLabel]) reads an observable (identified by [ObservableEvent.label])
/// for the first time in a given run, establishing a dependency.
///
/// Emitido quando um [Observer]/`Computed`/`Effect` (identificado por
/// [trackerLabel]) lê um observável (identificado por
/// [ObservableEvent.label]) pela primeira vez em uma dada execução,
/// estabelecendo uma dependência.
class TrackEvent extends ObservableEvent {
  /// Creates a track-event: [trackerLabel] now depends on [dependencyLabel].
  ///
  /// Cria um evento de rastreamento: [trackerLabel] agora depende de
  /// [dependencyLabel].
  TrackEvent(this.trackerLabel, String dependencyLabel, {super.stackTrace})
    : super(dependencyLabel);

  /// Debug label of the [Observer]/`Computed`/`Effect` doing the tracking.
  ///
  /// Rótulo de debug do [Observer]/`Computed`/`Effect` que está rastreando.
  final String trackerLabel;
}

/// Emitted for a misuse warning (empty [Observer]/`Effect`, write during
/// build, possible listener leak, write after dispose, ...).
///
/// Emitido para um warning de mau uso ([Observer]/`Effect` vazio, escrita
/// durante build, possível vazamento de listener, escrita após dispose,
/// ...).
class WarningEvent extends ObservableEvent {
  /// Creates a warning-event with [message] and an optional [suggestion].
  ///
  /// Cria um evento de warning com [message] e uma [suggestion] opcional.
  WarningEvent(super.message, {this.suggestion, super.stackTrace});

  /// Suggested fix, if any.
  ///
  /// Correção sugerida, se houver.
  final String? suggestion;
}

/// Emitted every time an `Effect`'s body actually runs (including its
/// initial run).
///
/// Emitido toda vez que o corpo de um `Effect` de fato executa (incluindo
/// sua execução inicial).
class EffectEvent extends ObservableEvent {
  /// Creates an effect-run event for [label].
  ///
  /// Cria um evento de execução de effect para [label].
  EffectEvent(super.label, {super.stackTrace});
}

/// Emitted when a `ReactiveScope` is disposed, noting how many registered
/// disposers ran.
///
/// Emitido quando um `ReactiveScope` é descartado, anotando quantos
/// disposers registrados rodaram.
class ScopeDisposeEvent extends ObservableEvent {
  /// Creates a scope-dispose event for [label], noting that
  /// [disposedCount] registered disposers ran.
  ///
  /// Cria um evento de descarte de escopo para [label], anotando que
  /// [disposedCount] disposers registrados rodaram.
  ScopeDisposeEvent(super.label, this.disposedCount, {super.stackTrace});

  /// Number of registered disposers that ran during this disposal.
  ///
  /// Número de disposers registrados que rodaram durante este descarte.
  final int disposedCount;
}

/// Pluggable observability hook for `all_observer`. Implement this (or use
/// the bundled `ConsoleInspector`/[RecordingInspector]) and register
/// instances via `ObserverConfig.inspectors` to observe every
/// create/update/dispose/track/warning/effect-run event the package emits,
/// without depending on the hardcoded console logging.
///
/// Every method has a no-op default, so implementers only override what
/// they care about. An exception thrown by an inspector method is caught
/// and isolated by the caller — same principle as a throwing listener —
/// and never breaks the notification it was reporting on.
///
/// Gancho de observabilidade plugável do `all_observer`. Implemente esta
/// classe (ou use o `ConsoleInspector`/[RecordingInspector] já incluídos) e
/// registre instâncias via `ObserverConfig.inspectors` para observar todo
/// evento de criação/atualização/descarte/rastreamento/warning/execução-de
/// -effect que o pacote emite, sem depender do logging fixo no console.
///
/// Toda exceção lançada por um método de inspector é capturada e isolada
/// por quem chama — mesmo princípio de um listener que lança — e nunca
/// quebra a notificação que estava sendo reportada.
///
/// Observer Protocol consumers remain on this registration layer by
/// extending `ObserverProtocolInspector`; no method is added to this legacy
/// contract, preserving classes that use `implements ObserverInspector`.
///
/// Consumidores do Observer Protocol continuam nesta camada ao estender
/// `ObserverProtocolInspector`; nenhum método é adicionado ao contrato legado,
/// preservando classes que usam `implements ObserverInspector`.
abstract class ObserverInspector {
  /// Creates an inspector with no retained state.
  ///
  /// Cria um inspector sem estado retido.
  const ObserverInspector();

  /// Called when an observable/Computed is created.
  ///
  /// Chamado quando um observável/Computed é criado.
  void onCreate(ObservableCreateEvent event) {}

  /// Called when an observable/Computed notifies a value change.
  ///
  /// Chamado quando um observável/Computed notifica uma mudança de valor.
  void onUpdate(ObservableUpdateEvent event) {}

  /// Called when an observable/Computed is disposed.
  ///
  /// Chamado quando um observável/Computed é descartado.
  void onDispose(ObservableDisposeEvent event) {}

  /// Called when an Observer/Computed/Effect starts depending on an
  /// observable.
  ///
  /// Chamado quando um Observer/Computed/Effect passa a depender de um
  /// observável.
  void onTrack(TrackEvent event) {}

  /// Called for a misuse warning.
  ///
  /// Chamado para um warning de mau uso.
  void onWarning(WarningEvent event) {}

  /// Called every time an Effect's body runs.
  ///
  /// Chamado toda vez que o corpo de um Effect executa.
  void onEffectRun(EffectEvent event) {}

  /// Called when a `ReactiveScope` is disposed. Default: no-op — same
  /// pattern as every other event here, so inspectors that `extends` this
  /// class keep compiling unchanged. (An inspector that `implements` this
  /// class instead must add the override, exactly as with any event added
  /// in previous releases, e.g. [onEffectRun] in 1.3.0.)
  ///
  /// Chamado quando um `ReactiveScope` é descartado. Padrão: no-op — mesmo
  /// padrão de todos os outros eventos aqui, então inspectors que fazem
  /// `extends` desta classe continuam compilando sem mudanças. (Um
  /// inspector que faz `implements` precisa adicionar o override,
  /// exatamente como com qualquer evento adicionado em releases
  /// anteriores, ex.: [onEffectRun] na 1.3.0.)
  void onScopeDispose(ScopeDisposeEvent event) {}
}

/// Safely notifies every inspector in [inspectors] of [call], isolating any
/// exception an individual inspector throws (silently, in this pure-Dart
/// core helper — the Flutter layer's `ObserverLogger` wraps this with its
/// own colored debug-console report on top). Shared by any core file that
/// needs to fan out an event without importing Flutter.
///
/// Notifica com segurança todo inspector em [inspectors] com [call],
/// isolando qualquer exceção que um inspector individual lance
/// (silenciosamente, neste helper puro do core — a camada Flutter do
/// `ObserverLogger` envolve isto com seu próprio relatório colorido no
/// console de debug por cima). Compartilhado por qualquer arquivo do core
/// que precise despachar um evento sem importar Flutter.
void dispatchToInspectors(
  List<ObserverInspector> inspectors,
  void Function(ObserverInspector inspector) call,
) {
  if (inspectors.isEmpty) {
    return;
  }
  for (final ObserverInspector inspector in List<ObserverInspector>.of(
    inspectors,
  )) {
    try {
      call(inspector);
    } catch (_) {
      // Isolated on purpose: an inspector must never break the
      // create/update/dispose/track it was notified about.
    }
  }
}
