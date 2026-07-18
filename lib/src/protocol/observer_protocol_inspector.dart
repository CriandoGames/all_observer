import '../core/observer_inspector.dart';
import 'events/observer_protocol_event.dart';

/// Opt-in protocol capability registered through `ObserverConfig.inspectors`.
///
/// It extends the existing [ObserverInspector] layer instead of introducing
/// a second consumer registry. Existing inspectors remain source-compatible
/// because no method is added to [ObserverInspector] itself.
///
/// Capacidade opt-in registrada por `ObserverConfig.inspectors`. Ela estende
/// a camada [ObserverInspector] existente, sem criar um segundo registry nem
/// adicionar métodos ao contrato legado.
abstract class ObserverProtocolInspector extends ObserverInspector {
  /// Creates a stateless protocol inspector.
  ///
  /// Cria um inspector de protocolo sem estado.
  const ObserverProtocolInspector();

  /// Receives one ordered protocol event.
  ///
  /// Recebe um evento ordenado do protocolo.
  void onProtocolEvent(ObserverProtocolEvent event) {}
}
