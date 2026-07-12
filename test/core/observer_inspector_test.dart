import 'package:all_observer/src/core/typedefs.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

class _ThrowingInspector implements ObserverInspector {
  @override
  void onCreate(ObservableCreateEvent event) => throw StateError('boom');

  @override
  void onUpdate(ObservableUpdateEvent event) => throw StateError('boom');

  @override
  void onDispose(ObservableDisposeEvent event) => throw StateError('boom');

  @override
  void onTrack(TrackEvent event) => throw StateError('boom');

  @override
  void onWarning(WarningEvent event) => throw StateError('boom');

  @override
  void onEffectRun(EffectEvent event) => throw StateError('boom');

  // Required because this test double uses `implements` (not `extends`):
  // every event added to the interface needs an explicit override here —
  // same adjustment onEffectRun needed when it was added in 1.3.0.
  @override
  void onScopeDispose(ScopeDisposeEvent event) => throw StateError('boom');
}

void main() {
  tearDown(ObserverConfig.reset);

  group('ObserverInspector wiring', () {
    test('onCreate/onUpdate/onDispose fire for Observable', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      final Observable<int> count = Observable<int>(1, name: 'count');
      count.value = 2;
      count.close();

      expect(recorder.events.whereType<ObservableCreateEvent>(), hasLength(1));
      expect(recorder.events.whereType<ObservableUpdateEvent>(), hasLength(1));
      expect(recorder.events.whereType<ObservableDisposeEvent>(), hasLength(1));

      final ObservableUpdateEvent update = recorder.events
          .whereType<ObservableUpdateEvent>()
          .single;
      expect(update.oldValue, 1);
      expect(update.newValue, 2);
    });

    test('onTrack fires when a Computed depends on an Observable', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      final Observable<int> a = Observable<int>(1, name: 'a');
      final Computed<int> doubled = Computed<int>(
        () => a.value * 2,
        name: 'doubled',
      );
      doubled.value; // force first compute + tracking

      final List<TrackEvent> tracks = recorder.events
          .whereType<TrackEvent>()
          .toList();
      expect(tracks, isNotEmpty);
      expect(tracks.first.trackerLabel, contains('doubled'));
      expect(tracks.first.label, contains('a'));
    });

    test('onEffectRun fires on every effect execution', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      final Observable<int> count = Observable<int>(0);
      final Disposer dispose = effect(() => count.value, name: 'myEffect');
      count.value = 1;

      final List<EffectEvent> runs = recorder.events
          .whereType<EffectEvent>()
          .toList();
      expect(runs.length, 2); // initial + one re-run
      expect(
        runs.every((EffectEvent e) => e.label.contains('myEffect')),
        isTrue,
      );
      dispose();
    });

    test('onWarning fires for misuse warnings', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      effect(() {}); // never reads anything -> warning

      expect(recorder.events.whereType<WarningEvent>(), isNotEmpty);
    });

    test('a throwing inspector does not prevent the notification or other '
        'inspectors from running', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[
        _ThrowingInspector(),
        recorder,
      ];

      final Observable<int> count = Observable<int>(1);
      expect(() => count.value = 2, returnsNormally);

      expect(recorder.events.whereType<ObservableUpdateEvent>(), hasLength(1));
    });

    test('RecordingInspector caps events at maxEvents (ring buffer)', () {
      final RecordingInspector recorder = RecordingInspector(maxEvents: 3);
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      final Observable<int> count = Observable<int>(0);
      for (int i = 1; i <= 5; i++) {
        count.value = i;
      }

      expect(recorder.events.length, lessThanOrEqualTo(3));
    });

    test('captureStackTraces populates event.stackTrace', () {
      ObserverConfig.captureStackTraces = true;
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      final Observable<int> count = Observable<int>(1);
      count.value = 2;

      final ObservableUpdateEvent update = recorder.events
          .whereType<ObservableUpdateEvent>()
          .single;
      expect(update.stackTrace, isNotNull);
    });

    test('no stack trace captured by default', () {
      final RecordingInspector recorder = RecordingInspector();
      ObserverConfig.inspectors = <ObserverInspector>[recorder];

      final Observable<int> count = Observable<int>(1);
      count.value = 2;

      final ObservableUpdateEvent update = recorder.events
          .whereType<ObservableUpdateEvent>()
          .single;
      expect(update.stackTrace, isNull);
    });
  });
}
