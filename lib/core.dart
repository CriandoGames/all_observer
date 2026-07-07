/// Pure-Dart core of `all_observer`: the dependency tracker, listener
/// registry, batch/flush engine, typedefs, and observability primitives
/// (`ObserverInspector`, `RecordingInspector`), plus the `untracked()`
/// escape hatch, the `ReactiveScope`/`ScopedObserverMixin` scoped-cleanup
/// primitives, and the error-reporting hook — with **zero import of
/// `package:flutter`**. Usable from a CLI/server context, not just Flutter
/// apps.
///
/// This is a *subset* of `package:all_observer/all_observer.dart`:
/// `Observable`, `Computed`, `effect()`, the reactive collections, and the
/// `Observer`/`ObserverValue` widgets are not exported here yet — they
/// still depend on Flutter for `ValueListenable`/`kDebugMode`/console
/// logging. Import `all_observer.dart` for those, as before; this file
/// exists for tooling that wants the low-level reactive primitives
/// (`ListenerRegistry`, `BatchScope`, `DependencyTracker`) or the
/// observability types without pulling in Flutter at all.
///
/// Núcleo em Dart puro do `all_observer`: o rastreador de dependências, o
/// registro de listeners, o motor de batch/flush, os typedefs, e as
/// primitivas de observabilidade (`ObserverInspector`, `RecordingInspector`),
/// além da escapatória `untracked()`, das primitivas de limpeza escopada
/// `ReactiveScope`/`ScopedObserverMixin` e o gancho de relato de erros —
/// com **zero import de `package:flutter`**. Utilizável em um contexto de
/// CLI/servidor, não só em apps Flutter.
///
/// Este é um *subconjunto* de `package:all_observer/all_observer.dart`:
/// `Observable`, `Computed`, `effect()`, as coleções reativas e os widgets
/// `Observer`/`ObserverValue` ainda não são exportados aqui — eles ainda
/// dependem de Flutter para `ValueListenable`/`kDebugMode`/logging no
/// console. Importe `all_observer.dart` para isso, como antes; este arquivo
/// existe para ferramental que queira as primitivas reativas de baixo nível
/// (`ListenerRegistry`, `BatchScope`, `DependencyTracker`) ou os tipos de
/// observabilidade sem trazer Flutter junto.
library;

export 'src/core/batch_scope.dart';
export 'src/core/core_error_reporting.dart';
export 'src/core/core_computed.dart';
export 'src/core/core_observable.dart';
export 'src/core/dependency_tracker.dart';
// Engine v2: the package's preset over `package:all_observer/engine.dart`
// (the raw engine itself stays in its own entry point).
// Motor v2: o preset do pacote sobre `package:all_observer/engine.dart`
// (o motor cru em si continua no próprio ponto de entrada).
export 'src/core/engine_bridge.dart';
export 'src/core/listener_registry.dart';
export 'src/core/observable_store.dart';
export 'src/core/observer_inspector.dart';
export 'src/core/reactive_scope.dart';
export 'src/core/recording_inspector.dart';
export 'src/core/scoped_observer_mixin.dart';
export 'src/core/typedefs.dart';
export 'src/core/untracked.dart';
export 'src/errors/observer_cycle_error.dart';
export 'src/errors/observer_error.dart';
export 'src/logging/observer_config.dart';
export 'src/observable/observable_subscription.dart';
