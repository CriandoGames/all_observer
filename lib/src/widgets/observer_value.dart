import 'package:flutter/widgets.dart';

import '../observable/observable.dart';
import 'observer.dart';

/// Convenience widget for local, self-contained reactive state: it owns an
/// [Observable] of type [T] and rebuilds via [Observer] whenever it
/// changes, without requiring the caller to manage the observable's
/// lifecycle separately.
///
/// Widget de conveniência para estado reativo local e autocontido: ele
/// possui um [Observable] do tipo [T] e reconstrói via [Observer] sempre
/// que ele mudar, sem exigir que quem o utiliza gerencie o ciclo de vida
/// do observável separadamente.
///
/// Example / Exemplo:
/// ```dart
/// ObserverValue<ObservableBool>(
///   (data) => Switch(value: data.value, onChanged: (v) => data.value = v),
///   false.obs,
/// );
/// ```
class ObserverValue<T extends Observable<Object?>> extends StatelessWidget {
  /// Creates an [ObserverValue] wrapping [data], passing it to [builder] on
  /// every rebuild.
  ///
  /// Cria um [ObserverValue] envolvendo [data], passando-o para [builder]
  /// em cada reconstrução.
  const ObserverValue(this.builder, this.data, {super.key, this.name});

  /// Builds the widget subtree using the current [data].
  ///
  /// Constrói a subárvore de widgets usando o [data] atual.
  final Widget Function(T data) builder;

  /// The observable this widget renders and reacts to.
  ///
  /// O observável que este widget renderiza e ao qual reage.
  final T data;

  /// Optional debug label forwarded to the underlying [Observer].
  ///
  /// Rótulo de debug opcional repassado ao [Observer] subjacente.
  final String? name;

  @override
  Widget build(BuildContext context) {
    return Observer(() => builder(data), name: name);
  }
}
