/// Public Observer Protocol event/model surface.
///
/// This barrel keeps consumers independent from the internal folder layout
/// while events, models and snapshots remain split by responsibility.
///
/// Superfície pública de eventos/modelos do Observer Protocol. Este barrel
/// mantém consumidores independentes da organização interna das pastas.
library;

export 'events/node_events.dart';
export 'events/observer_protocol_event.dart';
export 'events/scope_events.dart';
export 'events/tracker_events.dart';
export 'events/warning_event.dart';
export 'model/observer_node.dart';
export 'model/observer_value_summary.dart';
export 'observer_protocol_inspector.dart';
export 'snapshot/observer_protocol_snapshot.dart';
