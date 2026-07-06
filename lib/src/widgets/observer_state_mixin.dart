import 'package:flutter/widgets.dart';

import '../core/reactive_scope.dart';
import '../core/typedefs.dart';
import '../effects/effect.dart';

/// Mixin for a [State] that owns reactive subscriptions (a manual
/// `ObservableSubscription`, a standalone `effect()`, or any other
/// [Disposer]-returning registration) and wants them disposed automatically
/// alongside the widget, instead of hand-rolling a `dispose()` override that
/// tracks its own list of disposers.
///
/// Use [autoDispose] to register any [Disposer] (including
/// `subscription.cancel`, `computed.close`, or any other tear-off with that
/// shape), or [autorun] as a shortcut for a standalone `effect()` that is
/// automatically disposed with the [State].
///
/// Since 1.4.0 this mixin is a thin layer over an internal [ReactiveScope]
/// (the same scope `ScopedObserverMixin` exposes for plain Dart classes) —
/// an internal refactor with the same public API. Registered disposers run
/// exactly once, in reverse registration (LIFO) order — resources created
/// last are torn down first, the usual teardown convention — and one
/// disposer throwing never prevents the others from running.
///
/// This mixin does **not** replace `Observer`: `Observer` is for rebuilding
/// a widget subtree in response to observable reads inside `build()`. This
/// mixin is for side effects and manual subscriptions a `State` sets up in
/// `initState` that have nothing to do with `build()` — e.g. calling
/// `Navigator.push` when a value changes, showing a `SnackBar`, or driving
/// an `AnimationController` from an observable.
///
/// Mixin para um [State] que possui subscrições reativas (uma
/// `ObservableSubscription` manual, um `effect()` autônomo, ou qualquer
/// outro registro que devolva um [Disposer]) e quer que sejam descartadas
/// automaticamente junto com o widget, em vez de reimplementar um
/// `dispose()` que controla sua própria lista de disposers.
///
/// Use [autoDispose] para registrar qualquer [Disposer] (incluindo
/// `subscription.cancel`, `computed.close`, ou qualquer outro tear-off com
/// essa forma), ou [autorun] como atalho para um `effect()` autônomo
/// descartado automaticamente com o [State].
///
/// Desde a 1.4.0 este mixin é uma camada fina sobre um [ReactiveScope]
/// interno (o mesmo escopo que `ScopedObserverMixin` expõe para classes
/// Dart puras) — um refactor interno, com a mesma API pública. Disposers
/// registrados rodam exatamente uma vez, em ordem inversa de registro
/// (LIFO) — recursos criados por último são derrubados primeiro, a
/// convenção usual de teardown — e um disposer que lança nunca impede os
/// demais de rodarem.
///
/// Este mixin **não** substitui o `Observer`: o `Observer` serve para
/// reconstruir uma subárvore de widgets em resposta a leituras de
/// observáveis dentro do `build()`. Este mixin serve para efeitos colaterais
/// e subscrições manuais que um `State` configura em `initState` e que não
/// têm relação com `build()` — ex.: chamar `Navigator.push` quando um valor
/// muda, mostrar uma `SnackBar`, ou conduzir um `AnimationController` a
/// partir de um observável.
///
/// Example / Exemplo:
/// ```dart
/// class _MyPageState extends State<MyPage> with ObserverStateMixin {
///   @override
///   void initState() {
///     super.initState();
///     autorun(() {
///       if (session.value.isExpired) {
///         Navigator.of(context).pushReplacementNamed('/login');
///       }
///     });
///   }
/// }
/// ```
mixin ObserverStateMixin<T extends StatefulWidget> on State<T> {
  // The scope is lazy (`late final`), but every public member of this mixin
  // goes through it, so it exists by the time anything can be registered —
  // and `dispose()` below touches it unconditionally, so a State that never
  // registered anything still disposes a (empty) scope, keeping the
  // "registering after dispose runs the disposer immediately" contract.
  //
  // O escopo é preguiçoso (`late final`), mas todo membro público deste
  // mixin passa por ele, então ele existe quando qualquer coisa puder ser
  // registrada — e o `dispose()` abaixo o toca incondicionalmente, então um
  // State que nunca registrou nada ainda descarta um escopo (vazio),
  // mantendo o contrato de "registrar após o dispose roda o disposer
  // imediatamente".
  late final ReactiveScope _scope = ReactiveScope(name: '$runtimeType');

  /// Registers [disposer] to be called automatically when this [State] is
  /// disposed. Safe to call multiple times; every registered disposer runs
  /// exactly once, in reverse registration (LIFO) order.
  ///
  /// If [autoDispose] is called *after* this [State] has already been
  /// disposed (a programming error — nothing should be registering new
  /// subscriptions on a dead [State]), [disposer] runs immediately instead
  /// of being silently dropped, so resources are never leaked even in that
  /// case; a warning is dispatched to `ObserverConfig.inspectors`, and
  /// under `ObserverConfig.strictMode` an `ObserverError` is thrown — the
  /// underlying [ReactiveScope.add] behavior.
  ///
  /// Registra [disposer] para ser chamado automaticamente quando este
  /// [State] for descartado. Seguro chamar múltiplas vezes; todo disposer
  /// registrado roda exatamente uma vez, em ordem inversa de registro
  /// (LIFO).
  ///
  /// Se [autoDispose] for chamado *depois* deste [State] já ter sido
  /// descartado (um erro de programação — nada deveria estar registrando
  /// novas subscrições em um [State] morto), [disposer] roda imediatamente
  /// em vez de ser silenciosamente descartado, para que recursos nunca
  /// vazem mesmo nesse caso; um warning é despachado para
  /// `ObserverConfig.inspectors`, e sob `ObserverConfig.strictMode` um
  /// `ObserverError` é lançado — o comportamento subjacente de
  /// [ReactiveScope.add].
  void autoDispose(Disposer disposer) => _scope.add(disposer);

  /// Shortcut for a standalone `effect()` (see its own doc for the tracking
  /// contract) that is automatically disposed alongside this [State] —
  /// equivalent to `autoDispose(effect(run, name: name))`.
  ///
  /// Atalho para um `effect()` autônomo (ver seu próprio doc para o
  /// contrato de rastreamento) que é automaticamente descartado junto com
  /// este [State] — equivalente a `autoDispose(effect(run, name: name))`.
  Disposer autorun(void Function() run, {String? name}) {
    final Disposer disposer = effect(run, name: name);
    autoDispose(disposer);
    return disposer;
  }

  @override
  void dispose() {
    _scope.dispose();
    super.dispose();
  }
}
