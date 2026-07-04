import '../core/typedefs.dart';
import '../observable/observable.dart';
import '../observable/observable_subscription.dart';
import 'debouncer.dart';

/// Handle returned by [ever], [once], [debounce] and [interval], letting
/// the caller stop listening.
///
/// Handle retornado por [ever], [once], [debounce] e [interval],
/// permitindo que quem chamou pare de escutar.
class Worker {
  Worker._(this._dispose);

  final void Function() _dispose;
  bool _disposed = false;

  /// Whether [dispose] has already been called.
  ///
  /// Se [dispose] já foi chamado.
  bool get isDisposed => _disposed;

  /// Stops the worker. Safe to call more than once.
  ///
  /// Encerra o worker. Seguro chamar mais de uma vez.
  void dispose() {
    if (_disposed) {
      return;
    }
    _disposed = true;
    _dispose();
  }
}

/// A disposable group of [Worker]s, so several can be created together and
/// torn down with a single call.
///
/// Um grupo descartável de [Worker]s, permitindo criar vários juntos e
/// encerrá-los com uma única chamada.
class Workers {
  /// Creates a group wrapping [workers].
  ///
  /// Cria um grupo envolvendo [workers].
  Workers(this.workers);

  /// The wrapped workers.
  ///
  /// Os workers envolvidos.
  final List<Worker> workers;

  /// Disposes every worker in the group.
  ///
  /// Descarta todos os workers do grupo.
  void dispose() {
    for (final Worker worker in workers) {
      worker.dispose();
    }
  }
}

/// Runs [callback] with the new value every time [observable] changes.
///
/// Executa [callback] com o novo valor toda vez que [observable] mudar.
Worker ever<T>(Observable<T> observable, ObserverCallback<T> callback) {
  final ObservableSubscription sub = observable.listen(callback);
  return Worker._(sub.cancel);
}

/// Runs [callback] once, the first time [observable] changes, then stops
/// listening automatically.
///
/// Executa [callback] uma única vez, na primeira mudança de [observable],
/// e então para de escutar automaticamente.
Worker once<T>(Observable<T> observable, ObserverCallback<T> callback) {
  late final ObservableSubscription sub;
  sub = observable.listen((T value) {
    sub.cancel();
    callback(value);
  });
  return Worker._(sub.cancel);
}

/// Runs [callback] with the latest value after [observable] stops
/// changing for [time].
///
/// Executa [callback] com o valor mais recente depois que [observable]
/// parar de mudar por [time].
Worker debounce<T>(
  Observable<T> observable,
  ObserverCallback<T> callback, {
  required Duration time,
}) {
  final Debouncer debouncer = Debouncer(time);
  final ObservableSubscription sub = observable.listen((T value) {
    debouncer.run(() => callback(value));
  });
  return Worker._(() {
    debouncer.cancel();
    sub.cancel();
  });
}

/// Runs [callback] with the latest value at most once per [time], while
/// [observable] keeps changing.
///
/// Executa [callback] com o valor mais recente no máximo uma vez por
/// [time], enquanto [observable] continuar mudando.
Worker interval<T>(
  Observable<T> observable,
  ObserverCallback<T> callback, {
  required Duration time,
}) {
  bool waiting = false;
  T? pendingValue;
  bool hasPending = false;
  Debouncer? cooldown;

  // Note: the trailing flush below intentionally does not re-arm another
  // cooldown. Doing so would leave a timer perpetually pending after every
  // emission even once the observable stops changing, which is both a
  // pointless resource (a live Timer with nothing left to do) and, in
  // tests, a "Timer still pending after dispose" failure. Idling back to
  // `waiting = false` is correct: a value arriving right after the flush
  // simply starts a fresh cooldown window on its own.
  //
  // Nota: o flush final abaixo propositalmente não rearma outro cooldown.
  // Fazer isso deixaria um timer pendente para sempre após cada emissão,
  // mesmo que o observável pare de mudar — o que é um recurso inútil (um
  // Timer vivo sem mais nada a fazer) e, em testes, uma falha de "Timer
  // ainda pendente após o dispose". Voltar a `waiting = false` está
  // correto: um valor que chegar logo após o flush simplesmente inicia sua
  // própria janela de cooldown.
  void scheduleCooldown() {
    waiting = true;
    cooldown = Debouncer(time)
      ..run(() {
        waiting = false;
        if (hasPending) {
          hasPending = false;
          final T value = pendingValue as T;
          callback(value);
        }
      });
  }

  final ObservableSubscription sub = observable.listen((T value) {
    if (!waiting) {
      callback(value);
      scheduleCooldown();
    } else {
      pendingValue = value;
      hasPending = true;
    }
  });

  return Worker._(() {
    cooldown?.cancel();
    sub.cancel();
  });
}
