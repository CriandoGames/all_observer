import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../core/dependency_tracker.dart';
import '../core/typedefs.dart';
import '../errors/observer_error.dart';
import '../logging/observer_config.dart';
import '../logging/observer_logger.dart';

/// Rebuilds automatically whenever any observable read inside the
/// [builder] changes its value. Dependencies are re-discovered on every
/// build, so conditional reads (an `if` that reads a different observable
/// on each pass) are supported naturally.
///
/// Implementation note: rebuild scheduling is implemented on top of
/// [State.setState] (rather than a bespoke [Element] subclass) because it
/// gives the same safety guarantees — a `mounted` check plus a
/// scheduler-phase-aware deferral — with less surface area to maintain.
///
/// Reconstrói automaticamente sempre que qualquer observável lido dentro
/// do [builder] tiver seu valor alterado. As dependências são
/// redescobertas a cada build, portanto leituras condicionais (um `if` que
/// lê um observável diferente em cada passagem) são suportadas
/// naturalmente.
///
/// Nota de implementação: o agendamento de rebuild é feito sobre
/// [State.setState] (em vez de uma subclasse de [Element] dedicada),
/// pois oferece as mesmas garantias de segurança — checagem de `mounted`
/// mais um adiamento ciente da fase do scheduler — com menos superfície
/// para manter.
///
/// Example / Exemplo:
/// ```dart
/// final count = 0.obs;
/// Observer(() => Text('${count.value}'));
/// ```
class Observer extends StatefulWidget {
  /// Creates an [Observer] running [builder] on every rebuild. An optional
  /// [name] is used in debug logs and warnings.
  ///
  /// Cria um [Observer] que executa [builder] em cada reconstrução. Um
  /// [name] opcional é usado nos logs e warnings de debug.
  const Observer(this.builder, {super.key, this.name})
    : _staticChild = null,
      _childBuilder = null;

  /// Creates an [Observer] that rebuilds only the part of the subtree
  /// [builder] itself constructs, reusing the same, already-built [child]
  /// widget on every rebuild instead of reconstructing it — a static child
  /// subtree, a common technique for avoiding rebuilds of expensive widgets
  /// that don't depend on any observable. [child] is passed back to
  /// [builder] on every rebuild so it can be placed anywhere in the
  /// returned subtree (e.g. wrapped by a `Row`/`Padding`/`Center` that does
  /// change).
  ///
  /// Cria um [Observer] que reconstrói apenas a parte da subárvore que o
  /// próprio [builder] constrói, reaproveitando o mesmo widget [child] já
  /// construído a cada rebuild em vez de reconstruí-lo — uma subárvore
  /// estática, uma técnica comum para evitar reconstruções de widgets caros
  /// que não dependem de nenhum observável. [child] é repassado para
  /// [builder] a cada rebuild, para que possa ser posicionado em qualquer
  /// lugar da subárvore retornada (ex.: envolvido por um `Row`/`Padding`/
  /// `Center` que muda).
  ///
  /// Example / Exemplo:
  /// ```dart
  /// Observer.withChild(
  ///   builder: (context, child) => Row(
  ///     children: [Text('${count.value}'), child],
  ///   ),
  ///   child: const ExpensiveStaticWidget(),
  /// );
  /// ```
  const Observer.withChild({
    required Widget Function(BuildContext context, Widget child) builder,
    required Widget child,
    super.key,
    this.name,
  }) : _staticChild = child,
       builder = _unusedBuilder,
       _childBuilder = builder;

  static Widget _unusedBuilder() => const SizedBox.shrink();

  /// Builds the widget subtree, reading whichever observables are needed.
  /// Unused (and never called) when this [Observer] was created via
  /// [Observer.withChild] — [_childBuilder] is used instead.
  ///
  /// Constrói a subárvore de widgets, lendo os observáveis necessários. Não
  /// usado (e nunca chamado) quando este [Observer] foi criado via
  /// [Observer.withChild] — [_childBuilder] é usado no lugar.
  final Widget Function() builder;

  /// Set only by [Observer.withChild]: builds the subtree given the static
  /// [_staticChild], instead of taking no arguments.
  ///
  /// Definido apenas por [Observer.withChild]: constrói a subárvore
  /// recebendo o [_staticChild] estático, em vez de não receber argumentos.
  final Widget Function(BuildContext context, Widget child)? _childBuilder;

  /// The static child passed to [_childBuilder] on every rebuild, set only
  /// by [Observer.withChild].
  ///
  /// O filho estático repassado para [_childBuilder] a cada rebuild,
  /// definido apenas por [Observer.withChild].
  final Widget? _staticChild;

  /// Optional debug label shown in logs and warnings.
  ///
  /// Rótulo de debug opcional exibido em logs e warnings.
  final String? name;

  @override
  State<Observer> createState() => _ObserverState();
}

class _ObserverState extends State<Observer> {
  List<Disposer> _disposers = <Disposer>[];

  String get _label => 'Observer(${widget.name ?? 'sem-nome'})';

  void _clearDependencies() {
    for (final Disposer dispose in _disposers) {
      dispose();
    }
    _disposers = <Disposer>[];
  }

  void _onDependencyChanged() {
    if (!mounted) {
      return;
    }
    final SchedulerPhase phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((Duration _) {
        if (mounted) {
          setState(() {});
        }
      });
    } else {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _clearDependencies();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _clearDependencies();
    final TrackingContext trackingContext = TrackingContext(
      _onDependencyChanged,
      ownerLabel: _label,
    );
    try {
      final Widget Function() runBuilder = widget._childBuilder != null
          ? () => widget._childBuilder!(context, widget._staticChild!)
          : widget.builder;
      final Widget result = DependencyTracker.track(
        trackingContext,
        runBuilder,
      );
      _checkTracking(trackingContext);
      return result;
    } finally {
      // Assign disposers even if `widget.builder` threw above: whatever
      // observables were read before the throw must still be disposed of
      // on the next build/unmount, not silently dropped. The tracking
      // stack itself is already guaranteed to pop via
      // DependencyTracker.track's own `finally`.
      //
      // Atribui os disposers mesmo se `widget.builder` lançar acima: quaisquer
      // observáveis lidos antes do erro ainda devem ser descartados no
      // próximo build/unmount, não silenciosamente perdidos. A pilha de
      // rastreamento em si já tem garantia de ser desempilhada pelo
      // próprio `finally` de DependencyTracker.track.
      _disposers = trackingContext.disposers;
    }
  }

  void _checkTracking(TrackingContext trackingContext) {
    if (trackingContext.readCount == 0) {
      final String message =
          '$_label não leu nenhum Observable no '
          'builder. Ele nunca vai reconstruir.';
      if (ObserverConfig.strictMode) {
        throw ObserverError(message);
      }
      if (kDebugMode) {
        ObserverLogger.warn(
          message,
          suggestion: 'Você esqueceu o `.value` ou leu fora do escopo?',
        );
      }
      return;
    }
    if (kDebugMode) {
      ObserverLogger.tracked(_label, trackingContext.trackedLabels);
    }
  }
}
