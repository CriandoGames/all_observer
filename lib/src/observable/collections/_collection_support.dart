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

  /// Notifies listeners that the collection mutated. Call at the end of
  /// every mutating member.
  ///
  /// Notifica os listeners de que a coleção sofreu mutação. Chame ao fim
  /// de todo membro que muta o estado.
  void notifyChanged() {
    if (_isClosed) {
      if (kDebugMode) {
        ObserverLogger.warn(
          'Tentativa de alterar $debugLabel já descartado. Ignorado.',
        );
      }
      return;
    }
    _registry.notifyAll();
  }

  /// Subscribes [callback] to future mutations.
  ///
  /// Inscreve [callback] para mutações futuras.
  ObservableSubscription listen(VoidCallback callback, {bool immediate = false}) {
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
