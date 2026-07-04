import 'package:flutter/foundation.dart';

import 'typedefs.dart';

/// Holds the set of listeners attached to a single observable and notifies
/// them safely, tolerating listeners that add/remove other listeners during
/// notification.
///
/// Mantém o conjunto de listeners de um único observável e os notifica de
/// forma segura, tolerando listeners que adicionam/removem outros listeners
/// durante a notificação.
class ListenerRegistry {
  final List<VoidCallback> _listeners = <VoidCallback>[];

  /// Number of listeners currently attached.
  ///
  /// Número de listeners atualmente anexados.
  int get length => _listeners.length;

  /// Whether there is at least one listener attached.
  ///
  /// Se há ao menos um listener anexado.
  bool get hasListeners => _listeners.isNotEmpty;

  /// Adds [listener] if it is not already present and returns a [Disposer]
  /// that removes it.
  ///
  /// Adiciona [listener] se ele ainda não estiver presente e retorna um
  /// [Disposer] que o remove.
  Disposer add(VoidCallback listener) {
    if (!_listeners.contains(listener)) {
      _listeners.add(listener);
    }
    return () => remove(listener);
  }

  /// Whether [listener] is currently registered.
  ///
  /// Se [listener] está atualmente registrado.
  bool contains(VoidCallback listener) => _listeners.contains(listener);

  /// Removes [listener] if present.
  ///
  /// Remove [listener] se presente.
  void remove(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notifies a snapshot of the current listeners, so mutations made by a
  /// listener while notifying do not affect the current notification pass.
  ///
  /// Notifica uma cópia dos listeners atuais, de forma que mutações feitas
  /// por um listener durante a notificação não afetem o ciclo em andamento.
  void notifyAll() {
    if (_listeners.isEmpty) {
      return;
    }
    final List<VoidCallback> snapshot = List<VoidCallback>.of(_listeners);
    for (final VoidCallback listener in snapshot) {
      listener();
    }
  }

  /// Removes every listener. Called on dispose.
  ///
  /// Remove todos os listeners. Chamado no dispose.
  void clear() {
    _listeners.clear();
  }
}
