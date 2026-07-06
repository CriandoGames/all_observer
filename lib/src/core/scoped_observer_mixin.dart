import 'reactive_scope.dart';
import 'typedefs.dart';

/// Mixin for plain Dart classes (controllers, stores, services) that own
/// reactive resources and want them disposed with a single call — the
/// pure-Dart counterpart of `ObserverStateMixin`, with no `State`, no
/// `BuildContext`, and no `package:flutter` import.
///
/// Everything created inside [scoped] (a `Computed`, an `effect()`, a
/// worker) is registered in this object's internal [ReactiveScope]; any
/// other [Disposer]-shaped resource can be registered via [autoDispose] —
/// the same name and shape as `ObserverStateMixin.autoDispose`, kept
/// deliberately symmetric. Call [disposeScope] from your own teardown
/// method (a `close()`, `dispose()`, `onClose()`, ...) to release all of
/// it at once, in reverse registration (LIFO) order.
///
/// `scoped(fn)` was chosen (over an `initState`-style lifecycle hook)
/// because plain Dart classes have no framework-managed lifecycle to hang
/// such a hook on — a regular method that wraps any code block composes
/// with constructors, `late final` field initializers, and ordinary
/// methods alike, which is exactly how controllers create resources in
/// practice.
///
/// The internal scope is created lazily, on the first use of any member of
/// this mixin. If that first use happens to run inside *another* scope's
/// `run()`, this scope becomes its child (see [ReactiveScope]'s nesting
/// note); typically controllers are constructed outside any `run()` and no
/// nesting occurs.
///
/// Mixin para classes Dart puras (controllers, stores, services) que
/// possuem recursos reativos e querem descartá-los com uma única chamada —
/// a contraparte em Dart puro do `ObserverStateMixin`, sem `State`, sem
/// `BuildContext` e sem import de `package:flutter`.
///
/// Tudo que for criado dentro de [scoped] (um `Computed`, um `effect()`,
/// um worker) é registrado no [ReactiveScope] interno deste objeto;
/// qualquer outro recurso com forma de [Disposer] pode ser registrado via
/// [autoDispose] — mesmo nome e forma de `ObserverStateMixin.autoDispose`,
/// mantidos deliberadamente simétricos. Chame [disposeScope] no seu
/// próprio método de teardown (um `close()`, `dispose()`, `onClose()`,
/// ...) para liberar tudo de uma vez, em ordem inversa de registro (LIFO).
///
/// `scoped(fn)` foi a escolha (em vez de um gancho de ciclo de vida ao
/// estilo `initState`) porque classes Dart puras não têm um ciclo de vida
/// gerenciado por framework onde pendurar esse gancho — um método comum
/// que envolve qualquer bloco de código compõe igualmente com
/// construtores, inicializadores de campo `late final` e métodos comuns,
/// que é exatamente como controllers criam recursos na prática.
///
/// O escopo interno é criado preguiçosamente, no primeiro uso de qualquer
/// membro deste mixin. Se esse primeiro uso acontecer dentro do `run()` de
/// *outro* escopo, este escopo vira filho dele (ver a nota de aninhamento
/// de [ReactiveScope]); tipicamente controllers são construídos fora de
/// qualquer `run()` e nenhum aninhamento ocorre.
///
/// Example / Exemplo:
/// ```dart
/// class CounterController with ScopedObserverMixin {
///   final a = Observable<int>(1);
///   final b = Observable<int>(2);
///
///   late final Computed<int> total =
///       scoped(() => Computed(() => a.value + b.value));
///
///   CounterController() {
///     scoped(() {
///       effect(() => print('total: ${total.value}'));
///       ever(a, (_) => save());
///     });
///   }
///
///   void close() => disposeScope();
/// }
/// ```
mixin ScopedObserverMixin {
  /// The internal [ReactiveScope] owning every resource this mixin
  /// registered. Exposed for advanced composition (e.g. handing it to a
  /// child object, or manual inspection); most code only needs [scoped],
  /// [autoDispose] and [disposeScope].
  ///
  /// O [ReactiveScope] interno dono de todo recurso que este mixin
  /// registrou. Exposto para composição avançada (ex.: entregá-lo a um
  /// objeto filho, ou inspeção manual); a maior parte do código só precisa
  /// de [scoped], [autoDispose] e [disposeScope].
  late final ReactiveScope scope = ReactiveScope(name: '$runtimeType');

  /// Whether [disposeScope] has already been called.
  ///
  /// Se [disposeScope] já foi chamado.
  bool get isScopeDisposed => scope.isDisposed;

  /// Runs [fn] inside this object's scope and returns its result: every
  /// `Computed`/`effect()`/worker created inside [fn] is disposed by
  /// [disposeScope]. Sugar for `scope.run(fn)`.
  ///
  /// Executa [fn] dentro do escopo deste objeto e retorna seu resultado:
  /// todo `Computed`/`effect()`/worker criado dentro de [fn] é descartado
  /// por [disposeScope]. Açúcar para `scope.run(fn)`.
  R scoped<R>(R Function() fn) => scope.run(fn);

  /// Registers [disposer] to be called by [disposeScope] — same shape and
  /// intent as `ObserverStateMixin.autoDispose`, for resources the scope
  /// does not capture on its own (a `subscription.cancel`, an
  /// `observable.close`, ...). Sugar for `scope.add(disposer)`, including
  /// its already-disposed behavior (immediate disposal + warning, throw
  /// under `strictMode`).
  ///
  /// Registra [disposer] para ser chamado por [disposeScope] — mesma forma
  /// e intenção de `ObserverStateMixin.autoDispose`, para recursos que o
  /// escopo não captura sozinho (um `subscription.cancel`, um
  /// `observable.close`, ...). Açúcar para `scope.add(disposer)`,
  /// incluindo seu comportamento pós-descarte (descarte imediato +
  /// warning, throw sob `strictMode`).
  void autoDispose(Disposer disposer) => scope.add(disposer);

  /// Disposes everything registered so far, in reverse registration (LIFO)
  /// order. Idempotent. Call it from your class's own teardown method.
  ///
  /// Descarta tudo que foi registrado até agora, em ordem inversa de
  /// registro (LIFO). Idempotente. Chame-o no método de teardown da sua
  /// própria classe.
  void disposeScope() => scope.dispose();
}
