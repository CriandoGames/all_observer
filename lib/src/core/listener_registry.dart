import 'package:flutter/foundation.dart';

import '../logging/observer_logger.dart';
import 'batch_scope.dart';
import 'typedefs.dart';

/// Maximum notification depth allowed before [ListenerRegistry.notifyAll]
/// aborts with a descriptive error instead of overflowing the call stack.
/// Guards against update cycles (a listener of A writing B, whose listener
/// writes back to A, forever).
///
/// Profundidade máxima de notificação permitida antes que
/// [ListenerRegistry.notifyAll] aborte com um erro descritivo em vez de
/// estourar a pilha de chamadas. Protege contra ciclos de atualização (um
/// listener de A escrevendo em B, cujo listener escreve de volta em A,
/// indefinidamente).
const int kMaxNotificationDepth = 100;

int _notificationDepth = 0;

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
  /// listener while notifying do not affect the current notification pass
  /// (a listener that removes itself or adds another listener only affects
  /// the *next* notification, never the current one).
  ///
  /// Each listener runs inside its own `try`/`catch`: an exception thrown by
  /// one listener is reported via [FlutterError.reportError] (library
  /// `all_observer`) and does not prevent the remaining listeners of this
  /// same notification from running.
  ///
  /// A global notification-depth counter guards against update cycles (a
  /// listener of A writing to B, whose listener writes back to A, and so
  /// on): once [kMaxNotificationDepth] nested notifications are reached,
  /// this call stops recursing and reports a [FlutterError] instead of
  /// overflowing the stack.
  ///
  /// Notifica uma cópia dos listeners atuais, de forma que mutações feitas
  /// por um listener durante a notificação não afetem o ciclo em andamento
  /// (um listener que remove a si mesmo ou adiciona outro listener só afeta
  /// a *próxima* notificação, nunca a atual).
  ///
  /// Cada listener roda dentro do seu próprio `try`/`catch`: uma exceção
  /// lançada por um listener é reportada via [FlutterError.reportError]
  /// (biblioteca `all_observer`) e não impede que os demais listeners desta
  /// mesma notificação rodem.
  ///
  /// Um contador global de profundidade de notificação protege contra
  /// ciclos de atualização (um listener de A escrevendo em B, cujo listener
  /// escreve de volta em A, e assim por diante): ao atingir
  /// [kMaxNotificationDepth] notificações aninhadas, esta chamada para de
  /// recursar e reporta um [FlutterError] em vez de estourar a pilha.
  void notifyAll() {
    if (_listeners.isEmpty) {
      return;
    }
    if (_notificationDepth >= kMaxNotificationDepth) {
      final FlutterError cycleError = FlutterError(
        'all_observer: possible update cycle detected. Notification '
        'depth exceeded $kMaxNotificationDepth (a listener of one '
        'observable writes to another whose listener writes back, '
        'forever). Stopping this notification instead of overflowing '
        'the call stack. / Possível ciclo de atualização detectado: '
        'profundidade de notificação excedeu $kMaxNotificationDepth.',
      );
      ObserverLogger.caughtException(
        'possível ciclo de atualização detectado',
        cycleError,
      );
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: cycleError,
          library: 'all_observer',
          context: ErrorDescription('while notifying observable listeners'),
        ),
      );
      return;
    }
    final List<VoidCallback> snapshot = List<VoidCallback>.of(_listeners);
    _notificationDepth++;
    try {
      for (final VoidCallback listener in snapshot) {
        try {
          listener();
        } catch (error, stackTrace) {
          ObserverLogger.caughtException(
            'exceção isolada em um listener',
            error,
          );
          FlutterError.reportError(
            FlutterErrorDetails(
              exception: error,
              stack: stackTrace,
              library: 'all_observer',
              context: ErrorDescription(
                'while notifying an observable listener',
              ),
            ),
          );
        }
      }
    } finally {
      _notificationDepth--;
    }
  }

  /// Notifies immediately via [notifyAll], unless an `Observable.batch()`
  /// is currently active, in which case this registry is queued in
  /// [BatchScope] and notified exactly once when the outermost batch ends.
  /// Used by [Observable] and every reactive collection instead of calling
  /// [notifyAll] directly, so both participate in batching.
  ///
  /// Notifica imediatamente via [notifyAll], a menos que um
  /// `Observable.batch()` esteja atualmente ativo, caso em que este
  /// registro é enfileirado em [BatchScope] e notificado exatamente uma vez
  /// quando o batch mais externo terminar. Usado por [Observable] e toda
  /// coleção reativa em vez de chamar [notifyAll] diretamente, para que
  /// ambos participem do batching.
  void notifyOrQueue() {
    if (BatchScope.isActive) {
      BatchScope.queue(this);
      return;
    }
    notifyAll();
  }

  /// Removes every listener. Called on dispose.
  ///
  /// Remove todos os listeners. Chamado no dispose.
  void clear() {
    _listeners.clear();
  }
}
