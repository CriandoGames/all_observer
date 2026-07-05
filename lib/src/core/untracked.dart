import 'dependency_tracker.dart';

/// Runs [action] and returns its result without registering any observable
/// it reads as a dependency of whatever [Observer]/`Computed`/`Effect` is
/// currently tracking (if any). Use this when you need to read a value
/// inside a tracked callback without subscribing to it — most commonly
/// inside an `effect()` that writes to one observable based on reading
/// another one it does not want to re-run for.
///
/// ```dart
/// effect(() {
///   // Re-runs whenever `a` changes, but never because `log` changed.
///   final history = untracked(() => log.value);
///   print('a=${a.value}, history has ${history.length} entries');
/// });
/// ```
///
/// [Observable.peek] is sugar for `untracked(() => observable.value)` for
/// the common single-observable case.
///
/// Executa [action] e retorna seu resultado sem registrar nenhum observável
/// lido nele como dependência do [Observer]/`Computed`/`Effect` que estiver
/// rastreando no momento (se houver algum). Use isso quando precisar ler um
/// valor dentro de um callback rastreado sem se inscrever nele — mais
/// comumente dentro de um `effect()` que escreve em um observável com base
/// na leitura de outro do qual não quer depender.
///
/// [Observable.peek] é açúcar para `untracked(() => observable.value)` para
/// o caso comum de um único observável.
T untracked<T>(T Function() action) => DependencyTracker.untracked(action);
