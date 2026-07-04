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
  const Observer(this.builder, {super.key, this.name});

  /// Builds the widget subtree, reading whichever observables are needed.
  ///
  /// Constrói a subárvore de widgets, lendo os observáveis necessários.
  final Widget Function() builder;

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
    );
    final Widget result = DependencyTracker.track(
      trackingContext,
      widget.builder,
    );
    _disposers = trackingContext.disposers;
    _checkTracking(trackingContext);
    return result;
  }

  void _checkTracking(TrackingContext trackingContext) {
    if (trackingContext.readCount == 0) {
      final String message = '$_label não leu nenhum Observable no '
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
