import 'package:flutter/widgets.dart';

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
/// This mixin does **not** replace `Observer`: `Observer` is for rebuilding
/// a widget subtree in response to observable reads inside `build()`. This
/// mixin is for side effects and manual subscriptions a `State` sets up in
/// `initState` that have nothing to do with `build()` — e.g. calling
/// `Navigator.push` when a value changes, showing a `SnackBar`, or driving
/// an `AnimationController` from an observable.
///
/// Every registered disposer is called at most once, even if `dispose()`
/// somehow ran more than once — `State.dispose` doesn't in practice, but
/// this mixin doesn't rely on that not happening.
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
/// Este mixin **não** substitui o `Observer`: o `Observer` serve para
/// reconstruir uma subárvore de widgets em resposta a leituras de
/// observáveis dentro do `build()`. Este mixin serve para efeitos colaterais
/// e subscrições manuais que um `State` configura em `initState` e que não
/// têm relação com `build()` — ex.: chamar `Navigator.push` quando um valor
/// muda, mostrar uma `SnackBar`, ou conduzir um `AnimationController` a
/// partir de um observável.
///
/// Todo disposer registrado é chamado no máximo uma vez, mesmo que
/// `dispose()` de alguma forma rodasse mais de uma vez — `State.dispose` não
/// faz isso na prática, mas este mixin não depende disso.
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
  final List<Disposer> _autoDisposers = <Disposer>[];
  bool _disposed = false;

  /// Registers [disposer] to be called automatically when this [State] is
  /// disposed. Safe to call multiple times; every registered disposer runs,
  /// in registration order, exactly once.
  ///
  /// If [autoDispose] is called *after* this [State] has already been
  /// disposed (a programming error — nothing should be registering new
  /// subscriptions on a dead [State]), [disposer] runs immediately instead
  /// of being silently dropped, so resources are never leaked even in that
  /// case.
  ///
  /// Registra [disposer] para ser chamado automaticamente quando este
  /// [State] for descartado. Seguro chamar múltiplas vezes; todo disposer
  /// registrado roda, na ordem de registro, exatamente uma vez.
  ///
  /// Se [autoDispose] for chamado *depois* deste [State] já ter sido
  /// descartado (um erro de programação — nada deveria estar registrando
  /// novas subscrições em um [State] morto), [disposer] roda imediatamente
  /// em vez de ser silenciosamente descartado, para que recursos nunca
  /// vazem mesmo nesse caso.
  void autoDispose(Disposer disposer) {
    if (_disposed) {
      disposer();
      return;
    }
    _autoDisposers.add(disposer);
  }

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
    _disposed = true;
    // Snapshot into a *new* list before clearing — `_autoDisposers.clear()`
    // mutates the same list instance in place, so simply assigning the
    // reference first (without copying) would empty this snapshot too,
    // silently skipping every disposer.
    final List<Disposer> disposers = List<Disposer>.of(_autoDisposers);
    _autoDisposers.clear();
    for (final Disposer disposer in disposers) {
      disposer();
    }
    super.dispose();
  }
}
