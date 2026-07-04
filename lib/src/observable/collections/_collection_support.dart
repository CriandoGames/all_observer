import 'package:flutter/foundation.dart';

import '../../core/dependency_tracker.dart';
import '../../core/listener_registry.dart';
import '../../logging/observer_logger.dart';
import '../observable_subscription.dart';

/// Shared reactive plumbing reused by [ObservableList], [ObservableMap] and
/// [ObservableSet], so each collection only implements its own read/write
/// entry points around [reportRead] and [notifyChanged].
///
/// Internal: not exported by the package barrel.
///
/// Infraestrutura reativa compartilhada por [ObservableList], [ObservableMap]
/// e [ObservableSet], de forma que cada coleção implemente apenas seus
/// próprios pontos de leitura/escrita em torno de [reportRead] e
/// [notifyChanged].
///
/// Interno: não exportado pelo barrel do pacote.
mixin CollectionSupport {
  final ListenerRegistry _registry = ListenerRegistry();
  bool _isClosed = false;

  /// Debug label used in logs; overridden by each collection.
  ///
  /// Rótulo de debug usado nos logs; sobrescrito por cada coleção.
  String get debugLabel;

  /// Whether [close] has already been called.
  ///
  /// Se [close] já foi chamado.
  bool get isClosed => _isClosed;

  /// Registers the active [Observer] (if any) as a listener of this
  /// collection. Call at the top of every read-only member.
  ///
  /// Registra o [Observer] ativo (se houver) como listener desta coleção.
  /// Chame no início de todo membro somente-leitura.
  void reportRead() {
    DependencyTracker.reportRead(_registry, label: debugLabel);
  }

  /// Whether a mutating member should skip its write entirely because this
  /// collection is already [close]d. Call this *before* touching the
  /// underlying storage in every mutating member, and return early (with a
  /// no-op-appropriate value) if it returns `true` — mirroring
  /// `Observable.value`'s setter, where a write after [close] is a full
  /// no-op, not just a suppressed notification. Prints a debug warning the
  /// first time this happens for a given call.
  ///
  /// Se um membro mutante deve pular sua escrita inteiramente porque esta
  /// coleção já foi [close]d. Chame isso *antes* de tocar no armazenamento
  /// interno em todo membro mutante, e retorne cedo (com um valor
  /// apropriado de no-op) se retornar `true` — espelhando o setter de
  /// `Observable.value`, em que uma escrita após [close] é um no-op
  /// completo, não apenas uma notificação suprimida. Imprime um warning de
  /// debug a cada chamada em que isso ocorre.
  bool get isMutationBlocked {
    if (!_isClosed) {
      return false;
    }
    if (kDebugMode) {
      ObserverLogger.warn(
        'Tentativa de alterar $debugLabel já descartado. Ignorado.',
      );
    }
    return true;
  }

  /// Notifies listeners that the collection mutated. Call at the end of
  /// every mutating member, after already checking [isMutationBlocked].
  ///
  /// The `_isClosed` check here is a defensive safety net only (mutating
  /// members are expected to have already returned early via
  /// [isMutationBlocked] before ever reaching this point) — it deliberately
  /// does not warn again, to avoid a duplicate message.
  ///
  /// Notifica os listeners de que a coleção sofreu mutação. Chame ao fim
  /// de todo membro que muta o estado, depois de já ter checado
  /// [isMutationBlocked].
  ///
  /// A checagem de `_isClosed` aqui é apenas uma rede de segurança
  /// defensiva (membros mutantes já devem ter retornado cedo via
  /// [isMutationBlocked] antes de chegar aqui) — propositalmente não emite
  /// um segundo warning, para evitar mensagem duplicada.
  void notifyChanged() {
    if (_isClosed) {
      return;
    }
    ObserverLogger.checkWriteDuringBuild(debugLabel);
    _registry.notifyOrQueue();
  }

  /// Subscribes [callback] to future mutations. If this collection is
  /// already [close]d, returns an already-canceled (inert) subscription
  /// and never registers a listener.
  ///
  /// Inscreve [callback] para mutações futuras. Se esta coleção já tiver
  /// sido [close]d, retorna uma subscrição já cancelada (inerte) e nunca
  /// registra um listener.
  ObservableSubscription listen(
    VoidCallback callback, {
    bool immediate = false,
  }) {
    if (_isClosed) {
      if (immediate) {
        callback();
      }
      final ObservableSubscription inert = ObservableSubscription.fromDisposer(
        () {},
      );
      inert.cancel();
      return inert;
    }
    final void Function() dispose = _registry.add(callback);
    if (immediate) {
      callback();
    }
    return ObservableSubscription.fromDisposer(dispose);
  }

  /// Disposes the collection: removes all listeners and marks it closed.
  ///
  /// Descarta a coleção: remove todos os listeners e a marca como
  /// fechada.
  void close() {
    if (_isClosed) {
      return;
    }
    final int removed = _registry.length;
    _registry.clear();
    _isClosed = true;
    if (kDebugMode) {
      ObserverLogger.disposed(debugLabel, removed);
    }
  }
}
