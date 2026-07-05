import 'package:flutter/foundation.dart';

import '../core/core_computed.dart';
import '../logging/observer_logger.dart';
import 'observable_subscription.dart';

/// A read-only [ValueListenable] whose value is derived from other
/// observables via [compute], reusing the same stack-based
/// `DependencyTracker` that [Observer] uses — no separate tracking
/// mechanism.
///
/// Lazy: [compute] never runs before the first read of [value]. Memoized:
/// subsequent reads return the cached value without recomputing, until a
/// dependency notifies. Only notifies its own listeners when the
/// recomputed value actually differs (`==`) from the previous one, so a
/// dependency changing without affecting the derived result causes no
/// downstream rebuild. Supports dynamic/conditional dependencies: an `if`
/// inside [compute] that reads a different observable on each run is
/// tracked correctly, exactly like inside an [Observer] builder.
///
/// Um [ValueListenable] somente leitura cujo valor é derivado de outros
/// observáveis via [compute], reaproveitando o mesmo `DependencyTracker`
/// baseado em pilha que o [Observer] usa — nenhum mecanismo de
/// rastreamento separado.
///
/// Preguiçoso (lazy): [compute] nunca roda antes da primeira leitura de
/// [value]. Memoizado: leituras subsequentes retornam o valor em cache sem
/// recalcular, até que uma dependência notifique. Só notifica seus
/// próprios listeners quando o valor recalculado realmente difere (`==`)
/// do anterior, então uma dependência que muda sem afetar o resultado
/// derivado não causa rebuild a jusante. Suporta dependências
/// dinâmicas/condicionais: um `if` dentro de [compute] que lê um
/// observável diferente a cada execução é rastreado corretamente, assim
/// como dentro do builder de um [Observer].
///
/// This class is a thin `ValueListenable` + console-logging wrapper over
/// `CoreComputed`, the pure-Dart engine that owns the actual tracking/
/// memoization/glitch-free logic — see that class's doc for the shared
/// implementation, also usable standalone from `package:all_observer/
/// core.dart`.
///
/// Esta classe é um wrapper fino de `ValueListenable` + logging no console
/// sobre `CoreComputed`, o motor em Dart puro que possui a lógica real de
/// rastreamento/memoização/livre-de-glitch — ver o doc daquela classe para
/// a implementação compartilhada, também utilizável de forma autônoma a
/// partir de `package:all_observer/core.dart`.
///
/// Example / Exemplo:
/// ```dart
/// final firstName = 'Carlos'.obs;
/// final lastName = 'Castro'.obs;
/// final fullName = Computed(() => '${firstName.value} ${lastName.value}');
/// Observer(() => Text(fullName.value)); // recomputes only when needed
/// ```
class Computed<T> implements ValueListenable<T> {
  /// Creates a [Computed] that derives its value by running [compute]. An
  /// optional [name] is used in debug logs. [compute] does not run until
  /// [value] is first read.
  ///
  /// [equals] overrides the default `==` comparison used to decide whether
  /// a recomputed value actually changed (and therefore should notify).
  /// Useful for types whose `==` is not meaningful for this purpose (e.g.
  /// comparing only a subset of fields, or floating-point values within a
  /// tolerance). Defaults to `(a, b) => a == b`.
  ///
  /// Cria um [Computed] que deriva seu valor executando [compute]. Um
  /// [name] opcional é usado nos logs de debug. [compute] não roda até que
  /// [value] seja lido pela primeira vez.
  ///
  /// [equals] sobrescreve a comparação `==` padrão usada para decidir se um
  /// valor recalculado realmente mudou (e, portanto, deve notificar). Útil
  /// para tipos cujo `==` não é significativo para este propósito (ex.:
  /// comparar apenas um subconjunto de campos, ou valores de ponto
  /// flutuante dentro de uma tolerância). Padrão: `(a, b) => a == b`.
  Computed(T Function() compute, {String? name, bool Function(T a, T b)? equals})
    : _core = CoreComputed<T>(compute, name: name, equals: equals);

  /// The pure-Dart engine this class wraps — see `CoreComputed`'s class
  /// doc.
  ///
  /// O motor em Dart puro que esta classe envolve — ver o doc de classe de
  /// `CoreComputed`.
  final CoreComputed<T> _core;

  String get _label => _core.label;

  /// Whether [close] has already been called.
  ///
  /// Se [close] já foi chamado.
  bool get isClosed => _core.isClosed;

  @override
  T get value => _core.value;

  @override
  void addListener(VoidCallback listener) => _core.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _core.removeListener(listener);

  /// Subscribes [callback] to future recomputed values, mirroring
  /// `Observable.listen`.
  ///
  /// Inscreve [callback] para valores recalculados futuros, espelhando
  /// `Observable.listen`.
  ObservableSubscription listen(void Function(T value) callback) =>
      _core.listen(callback);

  /// Disposes this [Computed]: unsubscribes from all current dependencies
  /// and clears its own listeners. Safe to call more than once.
  ///
  /// Descarta este [Computed]: cancela a inscrição em todas as dependências
  /// atuais e limpa seus próprios listeners. Seguro chamar mais de uma vez.
  void close() {
    if (_core.isClosed) {
      return;
    }
    final int removed = _core.registry.length;
    _core.close();
    if (kDebugMode) {
      // dispatch: false — CoreComputed.close already dispatched
      // ObserverInspector.onDispose; this call is console-printing only.
      ObserverLogger.disposed(_label, removed, dispatch: false);
    }
  }
}
