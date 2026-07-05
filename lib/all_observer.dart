/// Lightweight reactive state management for Flutter, with zero external
/// dependencies. Exposes [Observable] values, derived [Computed] values,
/// standalone reactive `effect()`s, race-safe async state via
/// `ObservableFuture`/`AsyncState`, the auto-tracking [Observer] widget
/// (including `Observer.withChild` for static child subtrees), reactive
/// collections, manual subscriptions, `Observable.batch()`,
/// `Observable.select`, `untracked()`/`Observable.peek()` escape hatches,
/// and workers (`ever`, `once`, `debounce`, `interval`).
///
/// Gerenciamento de estado reativo e leve para Flutter, sem nenhuma
/// dependência externa. Expõe valores [Observable], valores derivados
/// [Computed], `effect()`s reativos autônomos, estado assíncrono seguro
/// contra corrida via `ObservableFuture`/`AsyncState`, o widget [Observer]
/// com auto-rastreamento (incluindo `Observer.withChild` para subárvores
/// filhas estáticas), coleções reativas, subscrições manuais,
/// `Observable.batch()`, `Observable.select`, as escapatórias
/// `untracked()`/`Observable.peek()` e workers (`ever`, `once`,
/// `debounce`, `interval`).
library;

export 'src/core/core_computed.dart';
export 'src/core/core_error_reporting.dart';
export 'src/core/core_observable.dart';
export 'src/core/observer_inspector.dart';
export 'src/core/recording_inspector.dart';
export 'src/core/untracked.dart';
export 'src/effects/effect.dart';
export 'src/errors/observer_cycle_error.dart';
export 'src/errors/observer_error.dart';
export 'src/logging/observer_config.dart';
export 'src/observable/async/async_state.dart';
export 'src/observable/async/observable_future.dart';
export 'src/observable/collections/observable_list.dart';
export 'src/observable/collections/observable_map.dart';
export 'src/observable/collections/observable_set.dart';
export 'src/observable/computed.dart';
export 'src/observable/observable.dart';
export 'src/observable/observable_extensions.dart';
export 'src/observable/observable_subscription.dart';
export 'src/observable/observable_types.dart';
export 'src/observable/select.dart';
export 'src/widgets/observer.dart';
export 'src/widgets/observer_value.dart';
export 'src/workers/workers.dart';
