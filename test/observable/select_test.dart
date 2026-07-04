import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/computed.dart';
import 'package:all_observer/src/observable/observable.dart';
import 'package:all_observer/src/observable/select.dart';

class _User {
  _User(this.name, this.age);
  final String name;
  final int age;
}

void main() {
  group('Observable.select', () {
    test('select derives a Computed from a projection of the value', () {
      final Observable<_User> user = Observable<_User>(_User('Carlos', 30));
      final Computed<String> userName = user.select((_User u) => u.name);
      expect(userName.value, 'Carlos');
      user.value = _User('Ana', 30);
      expect(userName.value, 'Ana');
      userName.close();
    });

    test('changing a non-selected field via refresh does not notify the '
        'select result', () {
      final Observable<_User> user = Observable<_User>(_User('Carlos', 30));
      final Computed<String> userName = user.select((_User u) => u.name);
      expect(userName.value, 'Carlos'); // forces first compute

      int calls = 0;
      userName.addListener(() => calls++);

      // refresh() notifies `user`'s listeners (including userName's
      // dependency tracking) without changing the underlying reference, so
      // the *name* projection is unaffected even though `user` "changed".
      user.refresh();
      expect(userName.value, 'Carlos');
      expect(calls, 0);
    });

    test('changing a different field to a new object still recomputes if '
        'the selected field also changed', () {
      final Observable<_User> user = Observable<_User>(_User('Carlos', 30));
      final Computed<int> userAge = user.select((_User u) => u.age);
      expect(userAge.value, 30);

      int calls = 0;
      userAge.addListener(() => calls++);

      // New object, but same age: `select`'s Computed still only notifies
      // if the *projected* value differs.
      user.value = _User('Ana', 30);
      expect(userAge.value, 30);
      expect(calls, 0);

      user.value = _User('Ana', 31);
      expect(userAge.value, 31);
      expect(calls, 1);
    });
  });

  group('Observable.select in a diamond/batch scenario', () {
    test('two select()-derived Computeds feeding a third Computed still '
        'recompute the bottom one exactly once, with fully consistent '
        'state, inside Observable.batch', () {
      final Observable<_User> user = Observable<_User>(_User('Carlos', 30));
      final Computed<String> name = user.select((_User u) => u.name);
      final Computed<int> age = user.select((_User u) => u.age);
      final List<String> seenSummaries = <String>[];
      final Computed<String> summary = Computed<String>(() {
        final String value = '${name.value} (${age.value})';
        seenSummaries.add(value);
        return value;
      });

      expect(summary.value, 'Carlos (30)');
      seenSummaries.clear();

      int summaryNotifications = 0;
      summary.addListener(() => summaryNotifications++);

      Observable.batch(() {
        user.value = _User('Ana', 31);
      });

      // Both `name` and `age` are derived from the same `user` write; the
      // bottom `summary` Computed must see the fully-updated pair (never
      // "Ana (30)" or "Carlos (31)") and recompute exactly once — the same
      // diamond glitch guarantee `Computed` documents, applying equally to
      // `select`'s sugar since it is plain `Computed` underneath.
      expect(summary.value, 'Ana (31)');
      expect(seenSummaries, <String>['Ana (31)']);
      expect(summaryNotifications, 1);

      name.close();
      age.close();
      summary.close();
    });
  });
}
