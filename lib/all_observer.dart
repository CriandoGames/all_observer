/// Lightweight reactive state management for Flutter, with zero external
/// dependencies. Exposes [Observable] values, derived [Computed] values,
/// the auto-tracking [Observer] widget, reactive collections, manual
/// subscriptions, `Observable.batch()`, and workers (`ever`, `once`,
/// `debounce`, `interval`).
///
/// Gerenciamento de estado reativo e leve para Flutter, sem nenhuma
/// dependência externa. Expõe valores [Observable], valores derivados
/// [Computed], o widget [Observer] com auto-rastreamento, coleções
/// reativas, subscrições manuais, `Observable.batch()` e workers (`ever`,
/// `once`, `debounce`, `interval`).
library;

export 'src/errors/observer_error.dart';
export 'src/logging/observer_config.dart';
export 'src/observable/collections/observable_list.dart';
export 'src/observable/collections/observable_map.dart';
export 'src/observable/collections/observable_set.dart';
export 'src/observable/computed.dart';
export 'src/observable/observable.dart';
export 'src/observable/observable_extensions.dart';
export 'src/observable/observable_subscription.dart';
export 'src/observable/observable_types.dart';
export 'src/widgets/observer.dart';
export 'src/widgets/observer_value.dart';
export 'src/workers/workers.dart';
