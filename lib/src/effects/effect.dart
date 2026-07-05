import 'package:flutter/foundation.dart' show kDebugMode;

import '../core/batch_scope.dart';
import '../core/dependency_tracker.dart';
import '../core/observer_inspector.dart';
import '../core/typedefs.dart';
import '../errors/observer_error.dart';
import '../logging/observer_config.dart';
import '../logging/observer_logger.dart';

/// Runs [run] immediately, then re-runs it whenever any observable read
/// during its previous run changes value — a standalone reactive effect,
/// with no [Observer] widget or `BuildContext` required. Reuses the same
/// stack-based dependency tracker as [Observer] and `Computed`, so
/// conditional/dynamic dependencies work identically: whatever [run] reads
/// *this* pass is what it depends on next, re-discovered from scratch on
/// every run.
///
/// Returns a [Disposer]: call it to stop [run] from ever executing again
/// and unsubscribe from all of its current dependencies.
///
/// Glitch-free scheduling: if multiple dependencies change inside an
/// `Observable.batch()` (explicit or the automatic per-write micro-batch),
/// [run] still executes at most once per batch, after every dependency has
/// settled to its final value — the same guarantee `Computed` provides.
///
/// Cycle protection: an effect that writes (directly or transitively) to
/// one of its own dependencies is bounded by the same notification-depth /
/// flush-wave guards used everywhere else in the package
/// (`kMaxNotificationDepth`, `kMaxFlushWaves`) — it will not recurse or
/// loop forever, and a descriptive error naming this effect is logged and
/// reported via `FlutterError.reportError` if it is ever caught throwing.
///
/// ```dart
/// final isLoggedIn = false.obs;
/// final user = Observable<User?>(null);
///
/// final dispose = effect(() {
///   if (isLoggedIn.value) {
///     print('user: ${user.value?.name}');
///   }
/// }, name: 'syncCart'); // runs immediately, then on every relevant change
///
/// dispose(); // cancels and unsubscribes from every dependency
/// ```
///
/// Workers (`ever`, `once`, `debounce`, `interval`) still exist and remain
/// the right tool for the common single-observable case — `effect` is for
/// callbacks that read more than one observable, or whose set of
/// dependencies changes conditionally between runs.
///
/// Executa [run] imediatamente, então o re-executa sempre que qualquer
/// observável lido durante sua execução anterior mudar de valor — um
/// efeito reativo autônomo, sem exigir um widget [Observer] ou
/// `BuildContext`. Reaproveita o mesmo rastreador de dependências baseado
/// em pilha que [Observer] e `Computed` usam, então dependências
/// condicionais/dinâmicas funcionam da mesma forma: o que [run] lê *nesta*
/// passagem é do que ele depende na próxima, redescoberto do zero a cada
/// execução.
///
/// Retorna um [Disposer]: chame-o para impedir que [run] execute de novo e
/// para cancelar a inscrição em todas as suas dependências atuais.
Disposer effect(void Function() run, {String? name}) {
  final _Effect instance = _Effect(run, name: name);
  return instance.dispose;
}

class _Effect {
  _Effect(this._run, {String? name}) : _name = name {
    _execute();
  }

  final void Function() _run;
  final String? _name;
  List<Disposer> _dependencyDisposers = <Disposer>[];
  bool _isDisposed = false;
  bool _dirty = false;
  bool _warnedEmptyOnce = false;

  String get _label => 'Effect(${_name ?? '#$hashCode'})';

  void _execute() {
    if (_isDisposed) {
      return;
    }
    _clearDependencies();
    final TrackingContext context = TrackingContext(
      _onDependencyChanged,
      ownerLabel: _label,
    );
    try {
      DependencyTracker.track(context, _run);
    } catch (error) {
      // Mirrors Computed._recompute: this effect does not swallow the
      // exception (the caller — ListenerRegistry.notifyAll's per-listener
      // catch, or BatchScope's per-callback catch — is still responsible
      // for that), it only adds a package-labeled log line naming this
      // effect before letting the exception propagate.
      //
      // Espelha Computed._recompute: este effect não engole a exceção (quem
      // chama — o catch por listener de ListenerRegistry.notifyAll, ou o
      // catch por callback de BatchScope — continua responsável por isso),
      // apenas adiciona uma linha de log com o nome deste effect antes de
      // deixar a exceção se propagar.
      if (kDebugMode) {
        ObserverLogger.caughtException('exceção em $_label', error);
      }
      rethrow;
    } finally {
      // Re-subscribe to whatever [_run] read this pass, even on failure —
      // see the identical reasoning in Computed._recompute's finally.
      //
      // Reinscreve nas dependências que [_run] leu nesta passagem, mesmo em
      // caso de falha — ver o mesmo raciocínio em Computed._recompute.
      _dependencyDisposers = context.disposers;
    }
    dispatchToInspectors(
      ObserverConfig.inspectors,
      (ObserverInspector i) => i.onEffectRun(
        EffectEvent(
          _label,
          stackTrace: ObserverConfig.captureStackTraces
              ? StackTrace.current
              : null,
        ),
      ),
    );
    if (kDebugMode && context.readCount == 0 && !_warnedEmptyOnce) {
      _warnedEmptyOnce = true;
      final String message =
          '$_label não leu nenhum observável no corpo. Ele nunca vai '
          're-executar.';
      if (ObserverConfig.strictMode) {
        throw ObserverError(message);
      }
      ObserverLogger.warn(
        message,
        suggestion: 'Você esqueceu o `.value` ou leu fora do escopo?',
      );
    }
  }

  // Same defer-during-batch / flush-once-after pattern as
  // Computed._onDependencyChanged — see that method's doc for the full
  // diamond-glitch rationale. An effect is, for scheduling purposes, just a
  // dependent with no cached value and no change-filtering.
  //
  // Mesmo padrão de adiar-durante-o-batch / flush-uma-vez-depois de
  // Computed._onDependencyChanged — ver o doc daquele método para o
  // raciocínio completo sobre o glitch do diamante. Um effect é, para fins
  // de agendamento, apenas um dependente sem valor em cache e sem filtro de
  // mudança.
  void _onDependencyChanged() {
    if (_isDisposed) {
      return;
    }
    if (BatchScope.isActive) {
      if (!_dirty) {
        _dirty = true;
        BatchScope.queueDirtyFlush(_flushIfDirty);
      }
      return;
    }
    _execute();
  }

  void _flushIfDirty() {
    if (_isDisposed || !_dirty) {
      return;
    }
    _dirty = false;
    _execute();
  }

  void _clearDependencies() {
    for (final Disposer dispose in _dependencyDisposers) {
      dispose();
    }
    _dependencyDisposers = <Disposer>[];
  }

  /// Stops [_run] from ever executing again and unsubscribes from every
  /// current dependency. Safe to call more than once.
  ///
  /// Impede que [_run] execute de novo e cancela a inscrição em toda
  /// dependência atual. Seguro chamar mais de uma vez.
  void dispose() {
    if (_isDisposed) {
      return;
    }
    _clearDependencies();
    _isDisposed = true;
  }
}
