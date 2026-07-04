import '../core/listener_registry.dart';
import '../core/typedefs.dart';

/// A handle returned by [Observable.listen] representing a manual
/// subscription, implemented directly over [ListenerRegistry] — no
/// `Stream` involved.
///
/// Um handle retornado por [Observable.listen] representando uma
/// subscrição manual, implementada diretamente sobre [ListenerRegistry] —
/// sem nenhum `Stream` envolvido.
class ObservableSubscription {
  ObservableSubscription._(this._dispose);

  /// Creates a subscription backed by [dispose], the [Disposer] returned
  /// when the listener was registered.
  ///
  /// Cria uma subscrição apoiada por [dispose], o [Disposer] retornado no
  /// registro do listener.
  factory ObservableSubscription.fromDisposer(Disposer dispose) {
    return ObservableSubscription._(dispose);
  }

  final Disposer _dispose;
  bool _active = true;

  /// Whether this subscription is still active (has not been canceled).
  ///
  /// Se esta subscrição ainda está ativa (não foi cancelada).
  bool get isActive => _active;

  /// Cancels the subscription. Safe to call more than once.
  ///
  /// Cancela a subscrição. Seguro chamar mais de uma vez.
  void cancel() {
    if (!_active) {
      return;
    }
    _active = false;
    _dispose();
  }
}
