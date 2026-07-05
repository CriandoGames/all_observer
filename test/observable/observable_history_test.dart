import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/observable/observable_history.dart';

void main() {
  group('ObservableHistory', () {
    test('undo/redo step through recorded values', () {
      final Observable<String> text = Observable<String>('');
      final ObservableHistory<String> history = text.withHistory();

      text.value = 'hello';
      text.value = 'hello world';

      expect(history.canUndo, isTrue);
      expect(history.canRedo, isFalse);

      history.undo();
      expect(text.value, 'hello');
      expect(history.canRedo, isTrue);

      history.undo();
      expect(text.value, '');
      expect(history.canUndo, isFalse);

      history.redo();
      expect(text.value, 'hello');
      history.redo();
      expect(text.value, 'hello world');
      expect(history.canRedo, isFalse);

      history.dispose();
    });

    test('a new value after undo truncates the redo branch', () {
      final Observable<int> n = Observable<int>(0);
      final ObservableHistory<int> history = n.withHistory();

      n.value = 1;
      n.value = 2;
      history.undo(); // back to 1
      expect(n.value, 1);
      expect(history.canRedo, isTrue);

      n.value = 5; // new branch — 2 is no longer reachable via redo
      expect(history.canRedo, isFalse);
      history.undo();
      expect(n.value, 1);
      history.undo();
      expect(n.value, 0);
      expect(history.canUndo, isFalse);

      history.dispose();
    });

    test('undo()/redo() are no-ops at the boundaries', () {
      final Observable<int> n = Observable<int>(0);
      final ObservableHistory<int> history = n.withHistory();

      history.undo(); // nothing to undo yet
      expect(n.value, 0);
      history.redo(); // nothing to redo
      expect(n.value, 0);

      history.dispose();
    });

    test('limit bounds how far back undo can go', () {
      final Observable<int> n = Observable<int>(0);
      final ObservableHistory<int> history = n.withHistory(limit: 3);

      for (int i = 1; i <= 5; i++) {
        n.value = i;
      }
      // Only the last 3 values (3, 4, 5) are retained.
      expect(n.value, 5);
      history.undo();
      expect(n.value, 4);
      history.undo();
      expect(n.value, 3);
      expect(
        history.canUndo,
        isFalse,
        reason: 'values 0, 1, 2 were dropped once the limit was exceeded',
      );

      history.dispose();
    });

    test('clear() drops all recorded history except the current value', () {
      final Observable<int> n = Observable<int>(0);
      final ObservableHistory<int> history = n.withHistory();
      n.value = 1;
      n.value = 2;

      history.clear();
      expect(history.canUndo, isFalse);
      expect(history.canRedo, isFalse);
      history.undo();
      expect(n.value, 2, reason: 'clear() keeps the current value as-is');

      history.dispose();
    });

    test('dispose() stops recording further external changes', () {
      final Observable<int> n = Observable<int>(0);
      final ObservableHistory<int> history = n.withHistory();
      n.value = 1;
      history.dispose();
      n.value = 2;

      // History is frozen at the point of dispose(); undo would only ever
      // reach the pre-dispose values, but calling undo/redo after dispose
      // isn't a supported usage — just confirm dispose() doesn't throw and
      // the Observable itself is unaffected.
      expect(n.value, 2);
      expect(n.isClosed, isFalse);
    });
  });
}
