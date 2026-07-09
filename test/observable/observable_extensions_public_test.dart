import 'package:all_observer/all_observer.dart';
import 'package:flutter_test/flutter_test.dart';

final class _Profile {
  const _Profile(this.name);

  final String name;
}

void main() {
  group('generic .obs extensions from the public barrel', () {
    test('wraps an object in Observable<T>', () {
      const _Profile profile = _Profile('Carlos');
      final Observable<_Profile> observed = profile.obs;

      expect(observed.value, same(profile));
      observed.close();
    });

    test('wraps List, Map and Set in their reactive collection types', () {
      final ObservableList<int> list = <int>[1, 2].obs;
      final ObservableMap<String, int> map = <String, int>{'a': 1}.obs;
      final ObservableSet<int> set = <int>{1, 2}.obs;

      expect(list, <int>[1, 2]);
      expect(map, <String, int>{'a': 1});
      expect(set, <int>{1, 2});

      list.close();
      map.close();
      set.close();
    });

    test('reactive collections copy their source collection', () {
      final List<int> source = <int>[1];
      final ObservableList<int> observed = source.obs;

      source.add(2);
      observed.add(3);

      expect(source, <int>[1, 2]);
      expect(observed, <int>[1, 3]);
      observed.close();
    });
  });
}
