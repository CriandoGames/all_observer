/// The public, reusable reactive-graph engine of `all_observer` (pure Dart,
/// zero imports of `package:flutter`).
///
/// This is the lowest layer of the package — below even
/// `package:all_observer/core.dart` — and it is intentionally **policy
/// -free**: it knows how to maintain a dependency graph (intrusive linked
/// lists), push staleness marks through it (`propagate`) and confirm
/// staleness lazily on read (`checkDirty`), but delegates *what updating a
/// node means*, *how effects are scheduled* and *what happens when a node
/// loses its last subscriber* to the three hooks of [ReactiveEngine]
/// (`update` / `notify` / `unwatched`).
///
/// It exists as a public entry point so that third parties can build their
/// own reactive layers (their own signal/computed/effect flavors, their own
/// scheduling) on top of the same engine — the same way `all_observer`'s
/// own `CoreObservable`/`CoreComputed` will (engine v2, Fase 2). As of
/// Fase 1 nothing inside `all_observer` consumes this layer yet; behavior
/// of the existing API is untouched.
///
/// The propagation model is push-pull: writes are cheap flag marks,
/// recomputation happens only when a value is actually pulled. (See the
/// license note in `src/engine/reactive_engine.dart`.)
///
/// O motor público e reutilizável de grafo reativo do `all_observer` (Dart
/// puro, zero imports de `package:flutter`).
///
/// Esta é a camada mais baixa do pacote — abaixo até de
/// `package:all_observer/core.dart` — e é intencionalmente **livre de
/// política**: ela sabe manter um grafo de dependências (listas ligadas
/// intrusivas), empurrar marcações de obsolescência por ele (`propagate`) e
/// confirmar obsolescência preguiçosamente na leitura (`checkDirty`), mas
/// delega *o que significa atualizar um nó*, *como effects são agendados* e
/// *o que acontece quando um nó perde seu último subscriber* aos três hooks
/// de [ReactiveEngine] (`update` / `notify` / `unwatched`).
///
/// Existe como ponto de entrada público para que terceiros construam suas
/// próprias camadas reativas (seus próprios sabores de signal/computed/
/// effect, seu próprio agendamento) sobre o mesmo motor — do mesmo jeito
/// que os `CoreObservable`/`CoreComputed` do próprio `all_observer` farão
/// (motor v2, Fase 2). Na Fase 1 nada dentro do `all_observer` consome esta
/// camada ainda; o comportamento da API existente está intocado.
///
/// O modelo de propagação é push-pull: escritas são marcações baratas de
/// flags, recomputação acontece só quando um valor é de fato puxado. (Ver
/// a nota de licença em `src/engine/reactive_engine.dart`.)
library;

export 'src/engine/reactive_engine.dart';
