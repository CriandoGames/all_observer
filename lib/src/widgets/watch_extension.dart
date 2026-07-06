import 'dart:async' show scheduleMicrotask;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../core/dependency_tracker.dart';
import '../core/typedefs.dart';
import '../errors/observer_error.dart';
import '../logging/observer_config.dart';
import '../logging/observer_logger.dart';
import '../observable/computed.dart';
import '../observable/observable.dart';
import 'rebuild_scheduler.dart';

// ---------------------------------------------------------------------------
// Element registry
// ---------------------------------------------------------------------------

/// Global `Element -> _ElementWatcher` registry. An [Expando] (not a `Map`)
/// so this file never holds a strong reference that could keep an unmounted
/// [Element] alive: an Expando entry lives exactly as long as its key is
/// otherwise reachable, and the watcher's own back-reference to its element
/// is safe — Expandos are ephemerons, so a value referencing its key does
/// not pin the pair. (This also makes the registry hot-reload-safe: elements
/// survive a hot reload, so their watchers simply survive with them, and the
/// per-build re-tracking below refreshes every subscription on the next
/// build anyway.)
///
/// Registro global `Element -> _ElementWatcher`. Um [Expando] (não um `Map`)
/// para este arquivo nunca segurar uma referência forte que mantenha vivo
/// um [Element] desmontado: uma entrada de Expando vive exatamente enquanto
/// sua chave for alcançável por outros meios, e a referência de volta do
/// watcher para seu element é segura — Expandos são ephemerons, então um
/// valor que referencia sua chave não prende o par. (Isso também torna o
/// registro seguro para hot reload: elements sobrevivem ao hot reload,
/// então seus watchers simplesmente sobrevivem com eles, e o re-tracking
/// por build abaixo renova toda assinatura no próximo build de qualquer
/// forma.)
final Expando<_ElementWatcher> _watchers = Expando<_ElementWatcher>(
  'all_observer watch(context) watchers',
);

/// Per-[Element] subscription holder for `watch(context)`.
///
/// New-build detection strategy: the first `watch` call of each build clears
/// the previous build's subscriptions and starts a fresh [TrackingContext];
/// subsequent `watch` calls of the *same* build reuse it. "Same build" is
/// tracked with a boolean armed by a [scheduleMicrotask]: an [Element] build
/// is fully synchronous, and microtasks only run once the current
/// synchronous span (the whole build/frame) has finished — so every `watch`
/// call inside one build sees the flag down, and the flag is guaranteed to
/// be up again before any *next* build can start (builds are initiated from
/// a later event/frame). This was chosen over a frame counter because it
/// needs no per-frame bookkeeping, works identically inside `flutter_test`
/// (which pumps microtasks between frames), and never misfires for builds
/// that happen outside a vsync-driven frame.
///
/// Suporte por-[Element] das assinaturas de `watch(context)`.
///
/// Estratégia de detecção de "novo build": a primeira chamada de `watch` de
/// cada build limpa as assinaturas do build anterior e inicia um
/// [TrackingContext] novo; as chamadas seguintes de `watch` do *mesmo*
/// build o reutilizam. "Mesmo build" é controlado com um booleano rearmado
/// por um [scheduleMicrotask]: o build de um [Element] é totalmente
/// síncrono, e microtasks só rodam quando o trecho síncrono atual (o
/// build/frame inteiro) terminou — então toda chamada de `watch` dentro de
/// um build vê a flag abaixada, e a flag tem garantia de estar levantada de
/// novo antes de qualquer *próximo* build começar (builds são iniciados a
/// partir de um evento/frame posterior). Escolhido em vez de um contador de
/// frame porque não exige contabilidade por frame, funciona igual dentro do
/// `flutter_test` (que processa microtasks entre frames) e nunca falha para
/// builds que aconteçam fora de um frame guiado por vsync.
class _ElementWatcher {
  _ElementWatcher(this._element);

  final Element _element;
  TrackingContext? _context;
  bool _newBuild = true;

  String get _label => 'Watch(${_element.widget.runtimeType})';

  T read<T>(ValueListenable<T> source) {
    if (_newBuild) {
      _newBuild = false;
      scheduleMicrotask(() => _newBuild = true);
      _disposeSubscriptions();
      // Reusing TrackingContext (rather than subscribing by hand) buys the
      // exact Observer semantics for free: per-registry deduplication, and
      // the same `ObserverInspector.onTrack` events, labeled with this
      // watcher instead of an Observer.
      //
      // Reutilizar TrackingContext (em vez de assinar manualmente) ganha de
      // graça a semântica exata do Observer: deduplicação por registro, e
      // os mesmos eventos `ObserverInspector.onTrack`, rotulados com este
      // watcher em vez de um Observer.
      _context = TrackingContext(_onDependencyChanged, ownerLabel: _label);
    }
    return DependencyTracker.track(_context!, () => source.value);
  }

  void _onDependencyChanged() {
    // Lazy cleanup (see `watch`'s doc): Element exposes no unmount hook to
    // third parties, so the first notification after unmount is where the
    // subscriptions get released and the watcher leaves the registry.
    //
    // Limpeza preguiçosa (ver o doc de `watch`): Element não expõe gancho
    // de unmount para terceiros, então a primeira notificação após o
    // unmount é onde as assinaturas são liberadas e o watcher sai do
    // registro.
    if (!_element.mounted) {
      _disposeSubscriptions();
      _watchers[_element] = null;
      return;
    }
    scheduleRebuildRespectingPhase(
      isMounted: () => _element.mounted,
      rebuild: _element.markNeedsBuild,
    );
  }

  void _disposeSubscriptions() {
    final TrackingContext? context = _context;
    _context = null;
    if (context == null) {
      return;
    }
    for (final Disposer dispose in context.disposers) {
      dispose();
    }
    context.disposers.clear();
  }
}

// ---------------------------------------------------------------------------
// Shared implementation
// ---------------------------------------------------------------------------

/// Shared body of both `watch` extensions below. Takes the narrowest type
/// both `Observable` and `Computed` share ([ValueListenable]) — but is
/// deliberately private instead of being itself an extension on
/// [ValueListenable]: reading `.value` only registers a dependency for
/// tracker-aware observables, so a public `watch` on any [ValueListenable]
/// would compile fine on a plain [ValueNotifier] and then silently never
/// rebuild. See the extensions' docs for the API-shape decision.
///
/// Corpo compartilhado das duas extensões `watch` abaixo. Recebe o tipo
/// mais estreito que `Observable` e `Computed` compartilham
/// ([ValueListenable]) — mas é deliberadamente privado em vez de ser ele
/// próprio uma extensão sobre [ValueListenable]: ler `.value` só registra
/// dependência para observáveis cientes do rastreador, então um `watch`
/// público sobre qualquer [ValueListenable] compilaria sem erro em um
/// [ValueNotifier] comum e então silenciosamente nunca reconstruiria. Ver
/// os docs das extensões para a decisão de forma da API.
T _watch<T>(ValueListenable<T> source, BuildContext context) {
  // Item "watch inside an Observer builder": when any tracking context is
  // already active (an Observer builder, a Computed's compute, an effect
  // body), just read the value — the read reports itself to that context,
  // which already owns re-running/rebuilding. Registering on the Element
  // *as well* would create a second, overlapping subscription whose
  // markNeedsBuild is redundant (the Observer's rebuild already rebuilds
  // this element's subtree), i.e. the "surprise double subscription" the
  // API contract rules out.
  //
  // Item "watch dentro de um builder de Observer": quando qualquer contexto
  // de rastreamento já está ativo (um builder de Observer, o compute de um
  // Computed, o corpo de um effect), apenas lê o valor — a leitura se
  // reporta àquele contexto, que já é dono de re-executar/reconstruir.
  // Registrar *também* no Element criaria uma segunda assinatura
  // sobreposta cujo markNeedsBuild é redundante (o rebuild do Observer já
  // reconstrói a subárvore deste element), ou seja, a "inscrição dupla
  // surpresa" que o contrato da API descarta.
  if (DependencyTracker.current != null) {
    return source.value;
  }
  if (kDebugMode) {
    // `BuildContext.debugDoingBuild` is the check the framework exposes for
    // "is this element currently running build()" (it is defined to always
    // return false in release builds, hence the kDebugMode gate — release
    // behavior is never affected).
    //
    // `BuildContext.debugDoingBuild` é a verificação que o framework expõe
    // para "este element está executando build() agora" (é definida para
    // sempre retornar false em builds de release, daí o gate de kDebugMode
    // — o comportamento em release nunca é afetado).
    if (!context.debugDoingBuild) {
      final String message =
          'watch(context) chamado fora do build() de '
          '${context.widget.runtimeType}. A assinatura não acompanha o '
          'ciclo de rebuild do Element.';
      if (ObserverConfig.strictMode) {
        throw ObserverError(message);
      }
      ObserverLogger.warn(
        message,
        suggestion:
            'Chame watch(context) apenas dentro de build(). Fora dele, use '
            'listen()/ever() ou um effect().',
      );
    }
  }
  final Element element = context as Element;
  final _ElementWatcher watcher =
      _watchers[element] ??= _ElementWatcher(element);
  return watcher.read(source);
}

// ---------------------------------------------------------------------------
// Public API
// ---------------------------------------------------------------------------

/// Lets any widget read an [Observable] inside its own `build()` and
/// subscribe its own [Element] to it — a surgical, per-widget rebuild with
/// no `Observer` wrapper needed.
///
/// API-shape decision: `Observable` and `Computed` share no supertype other
/// than [ValueListenable], and extending [ValueListenable] itself would
/// offer `watch` to plain [ValueNotifier]s, where it can never work (their
/// `.value` read does not report to the `DependencyTracker`). So there are
/// two thin extensions — this one and [ComputedWatchExtension] — each a
/// one-line delegate to a single shared private implementation: precise API,
/// no logic duplicated.
///
/// Permite que qualquer widget leia um [Observable] dentro do próprio
/// `build()` e inscreva seu próprio [Element] nele — um rebuild cirúrgico,
/// por widget, sem precisar de wrapper `Observer`.
///
/// Decisão de forma da API: `Observable` e `Computed` não compartilham
/// supertipo além de [ValueListenable], e estender o próprio
/// [ValueListenable] ofereceria `watch` a [ValueNotifier]s comuns, onde ele
/// nunca pode funcionar (a leitura de `.value` deles não se reporta ao
/// `DependencyTracker`). Então são duas extensões finas — esta e
/// [ComputedWatchExtension] — cada uma delegando em uma linha para uma
/// única implementação privada compartilhada: API precisa, nenhuma lógica
/// duplicada.
extension WatchExtension<T> on Observable<T> {
  /// Reads the current value and subscribes [context]'s [Element]: when
  /// this observable changes, only that element rebuilds — `Observer`
  /// semantics at the granularity of the calling widget.
  ///
  /// ```dart
  /// // In any build():
  /// Text('${count.watch(context)}');
  /// ```
  ///
  /// Dependencies are re-discovered on every build, exactly like inside an
  /// `Observer` builder: whatever this element `watch`es *this* build is
  /// what it depends on until its next build — conditional `watch`es on
  /// different observables per pass work naturally. Rebuild scheduling
  /// honors the scheduler phase the same way `Observer` does (a change
  /// during build/layout/paint defers the rebuild to a post-frame
  /// callback). Multiple observables watched by one element still coalesce
  /// into a single rebuild per batch/frame.
  ///
  /// Inside an `Observer` builder (or a `Computed`/`effect`), `watch`
  /// simply reports the read to that active tracking context and does
  /// *not* also subscribe the element — no surprise double subscription;
  /// the enclosing tracker alone owns the rebuild.
  ///
  /// **Lazy cleanup**: `Element` exposes no unmount hook to packages, so a
  /// subscription made by `watch` can outlive its element until the first
  /// notification after unmount — at that point it is a guaranteed no-op
  /// (nothing rebuilds, nothing throws) and every subscription of that
  /// element is released and the element leaves the internal registry. In
  /// other words: at most one extra (ignored) notification per observable,
  /// never a rebuild of a dead widget, never a permanent leak on
  /// observables that keep changing. An observable that *never* changes
  /// again keeps that inert listener — if that matters (e.g. a long-lived
  /// global observable and many short-lived screens), prefer `Observer`,
  /// whose `dispose()` cleans up eagerly.
  ///
  /// In debug mode, calling this outside `build()` logs a warning (and
  /// throws an `ObserverError` under `ObserverConfig.strictMode`) — the
  /// subscription would not follow the element's rebuild cycle.
  ///
  /// Lê o valor atual e inscreve o [Element] de [context]: quando este
  /// observável mudar, apenas aquele element reconstrói — a semântica do
  /// `Observer` na granularidade do widget chamador.
  ///
  /// As dependências são redescobertas a cada build, exatamente como
  /// dentro de um builder de `Observer`: o que este element observar com
  /// `watch` *neste* build é do que ele depende até o próximo build —
  /// `watch`es condicionais em observáveis diferentes por passagem
  /// funcionam naturalmente. O agendamento de rebuild respeita a fase do
  /// scheduler como o `Observer` (uma mudança durante build/layout/paint
  /// adia o rebuild para um callback pós-frame). Múltiplos observáveis
  /// observados por um element ainda se agrupam em um único rebuild por
  /// batch/frame.
  ///
  /// Dentro de um builder de `Observer` (ou de um `Computed`/`effect`), o
  /// `watch` apenas reporta a leitura àquele contexto de rastreamento
  /// ativo e *não* inscreve também o element — sem inscrição dupla
  /// surpresa; só o rastreador externo é dono do rebuild.
  ///
  /// **Limpeza preguiçosa**: `Element` não expõe gancho de unmount para
  /// pacotes, então uma assinatura feita por `watch` pode sobreviver ao
  /// seu element até a primeira notificação após o unmount — nesse ponto
  /// ela é um no-op garantido (nada reconstrói, nada lança) e todas as
  /// assinaturas daquele element são liberadas e o element sai do registro
  /// interno. Em outras palavras: no máximo uma notificação extra
  /// (ignorada) por observável, nunca um rebuild de widget morto, nunca um
  /// vazamento permanente em observáveis que continuam mudando. Um
  /// observável que *nunca mais* mudar mantém esse listener inerte — se
  /// isso importar (ex.: um observável global de vida longa e muitas telas
  /// de vida curta), prefira o `Observer`, cujo `dispose()` limpa
  /// avidamente.
  ///
  /// Em modo debug, chamar isto fora do `build()` registra um warning (e
  /// lança um `ObserverError` sob `ObserverConfig.strictMode`) — a
  /// assinatura não acompanharia o ciclo de rebuild do element.
  T watch(BuildContext context) => _watch<T>(this, context);
}

/// `watch(context)` for [Computed] — see [WatchExtension] for the full
/// contract (identical) and for why this is a separate extension rather
/// than one on [ValueListenable].
///
/// `watch(context)` para [Computed] — ver [WatchExtension] para o contrato
/// completo (idêntico) e para o porquê de esta ser uma extensão separada em
/// vez de uma sobre [ValueListenable].
extension ComputedWatchExtension<T> on Computed<T> {
  /// Reads the current (lazily computed) value and subscribes [context]'s
  /// [Element] — identical contract to [WatchExtension.watch].
  ///
  /// Lê o valor atual (calculado preguiçosamente) e inscreve o [Element]
  /// de [context] — contrato idêntico ao de [WatchExtension.watch].
  T watch(BuildContext context) => _watch<T>(this, context);
}
