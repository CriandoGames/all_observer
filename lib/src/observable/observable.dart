import 'package:all_observer/src/core/typedefs.dart';
import 'package:flutter/foundation.dart';

import '../core/dependency_tracker.dart';
import '../core/listener_registry.dart';
import '../logging/observer_config.dart';
import '../logging/observer_logger.dart';
import 'observable_subscription.dart';

/// A reactive holder of a value of type [T].
///
/// Reading [value] inside an [Observer] builder automatically registers
/// that Observer to rebuild when the value changes. [Observable] also
/// implements [ValueListenable], so it is directly usable with
/// [ValueListenableBuilder], `Listenable.merge`, or [AnimatedBuilder]
/// without any adapter.
///
/// Notification semantics are intentionally simple: a write only notifies
/// listeners when the new value is different from the current one
/// (`!=`). For mutable objects whose internal state changed without
/// replacing the reference, call [refresh] to force a notification.
///
/// Um contêiner reativo de um valor do tipo [T].
///
/// Ler [value] dentro do builder de um [Observer] registra automaticamente
/// aquele Observer para reconstruir quando o valor mudar. [Observable]
/// também implementa [ValueListenable], portanto é utilizável diretamente
/// com [ValueListenableBuilder], `Listenable.merge` ou [AnimatedBuilder]
/// sem nenhum adaptador.
///
/// A semântica de notificação é propositalmente simples: uma escrita só
/// notifica os listeners quando o novo valor é diferente do atual (`!=`).
/// Para objetos mutáveis cujo estado interno mudou sem substituir a
/// referência, chame [refresh] para forçar uma notificação.
///
/// Example / Exemplo:
/// ```dart
/// final count = 0.obs;
/// Observer(() => Text('${count.value}'));
/// count.value++;
/// ```
class Observable<T> implements ValueListenable<T> {
  /// Creates an observable holding [initialValue]. An optional [name] is
  /// used in debug logs and warnings; when omitted, a short hash-based
  /// label is used instead.
  ///
  /// Cria um observável contendo [initialValue]. Um [name] opcional é
  /// usado nos logs e warnings de debug; quando omitido, um rótulo curto
  /// baseado no hash é usado.
  Observable(T initialValue, {String? name})
    : _value = initialValue,
      _name = name {
    if (kDebugMode) {
      ObserverLogger.created(_label, _value);
    }
  }

  final ListenerRegistry _registry = ListenerRegistry();
  final String? _name;
  T _value;
  bool _isClosed = false;

  String get _label => '$runtimeType(${_name ?? '#$hashCode'})';

  /// Whether [close] has already been called on this observable.
  ///
  /// Se [close] já foi chamado neste observável.
  bool get isClosed => _isClosed;

  /// Whether this observable currently has at least one listener attached
  /// (an [Observer] tracking it, or a manual [listen]/[addListener] call).
  ///
  /// Se este observável tem atualmente ao menos um listener anexado (um
  /// [Observer] rastreando-o, ou uma chamada manual a [listen]/
  /// [addListener]).
  bool get hasListeners => _registry.hasListeners;

  @override
  T get value {
    DependencyTracker.reportRead(_registry, label: _label);
    return _value;
  }

  /// Assigns [newValue], notifying listeners only if it differs from the
  /// current value (`!=`). No-ops with a debug warning if the observable
  /// was already [close]d.
  ///
  /// Atribui [newValue], notificando os listeners apenas se ele for
  /// diferente do valor atual (`!=`). Não faz nada (com warning em debug)
  /// se o observável já tiver sido [close]d.
  set value(T newValue) {
    if (_isClosed) {
      if (kDebugMode) {
        ObserverLogger.warn(
          'Tentativa de alterar $_label já descartado. Ignorado.',
        );
      }
      return;
    }
    if (_value == newValue) {
      return;
    }
    _warnIfWritingDuringBuild();
    final T oldValue = _value;
    _value = newValue;
    if (kDebugMode) {
      ObserverLogger.updated(_label, oldValue, newValue);
    }
    notifyListeners();
  }

  void _warnIfWritingDuringBuild() {
    if (!kDebugMode) {
      return;
    }
    if (DependencyTracker.current != null) {
      ObserverLogger.warn(
        '$_label alterado DURANTE o build de um Observer.',
        suggestion:
            'Isso causa loop de rebuild. Mova a alteração para '
            'fora do build.',
      );
    }
  }

  /// Shorthand for assigning [newValue], mirroring `observable(newValue)`.
  ///
  /// Atalho para atribuir [newValue], equivalente a
  /// `observable(newValue)`.
  T call([T? newValue]) {
    if (newValue != null) {
      value = newValue;
    }
    return _value;
  }

  /// Forces listener notification without changing [value]. Use this after
  /// mutating a referenced object's internal state in place.
  ///
  /// Força a notificação dos listeners sem alterar [value]. Use após
  /// mutar o estado interno de um objeto referenciado, no próprio lugar.
  void refresh() {
    if (_isClosed) {
      return;
    }
    notifyListeners();
  }

  /// Subscribes [callback] to future value changes without going through
  /// an [Observer] widget. If [immediate] is `true`, [callback] also fires
  /// once immediately with the current value.
  ///
  /// Inscreve [callback] para mudanças futuras de valor sem passar por um
  /// widget [Observer]. Se [immediate] for `true`, [callback] também
  /// dispara uma vez imediatamente com o valor atual.
  ObservableSubscription listen(
    ObserverCallback<T> callback, {
    bool immediate = false,
  }) {
    void listener() => callback(_value);
    final void Function() dispose = _registry.add(listener);
    if (immediate) {
      callback(_value);
    }
    _warnIfPossibleLeak();
    return ObservableSubscription.fromDisposer(dispose);
  }

  void _warnIfPossibleLeak() {
    if (kDebugMode &&
        _registry.length >= ObserverConfig.listenerLeakThreshold) {
      ObserverLogger.warn(
        '$_label tem ${_registry.length}+ listeners. Possível vazamento.',
        suggestion: 'Observers sendo criados sem descarte?',
      );
    }
  }

  @override
  void addListener(VoidCallback listener) {
    _registry.add(listener);
    _warnIfPossibleLeak();
  }

  @override
  void removeListener(VoidCallback listener) {
    _registry.remove(listener);
  }

  /// Notifies every current listener. Exposed for subclasses (e.g.
  /// collections) that mutate internal state through means other than the
  /// [value] setter.
  ///
  /// Notifica todos os listeners atuais. Exposto para subclasses (ex.:
  /// coleções) que mutam o estado interno por outros meios além do setter
  /// [value].
  @protected
  void notifyListeners() {
    _registry.notifyAll();
  }

  /// Disposes this observable: removes all listeners and marks it
  /// [isClosed]. Subsequent writes are ignored with a debug warning.
  ///
  /// Descarta este observável: remove todos os listeners e o marca como
  /// [isClosed]. Escritas subsequentes são ignoradas com warning em debug.
  void close() {
    if (_isClosed) {
      return;
    }
    final int removed = _registry.length;
    _registry.clear();
    _isClosed = true;
    if (kDebugMode) {
      ObserverLogger.disposed(_label, removed);
    }
  }
}
