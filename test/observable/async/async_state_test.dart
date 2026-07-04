import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/src/observable/async/async_state.dart';

void main() {
  group('AsyncState', () {
    test('AsyncLoading getters and equality', () {
      const AsyncState<int> loading = AsyncLoading<int>(previousData: 1);
      expect(loading.isLoading, isTrue);
      expect(loading.hasData, isFalse);
      expect(loading.hasError, isFalse);
      expect(loading.valueOrNull, isNull);
      expect(loading, const AsyncLoading<int>(previousData: 1));
      expect(loading, isNot(const AsyncLoading<int>(previousData: 2)));
      expect(
        const AsyncLoading<int>(previousData: 1).hashCode,
        const AsyncLoading<int>(previousData: 1).hashCode,
      );
    });

    test('AsyncData getters and equality', () {
      const AsyncState<int> data = AsyncData<int>(42);
      expect(data.isLoading, isFalse);
      expect(data.hasData, isTrue);
      expect(data.hasError, isFalse);
      expect(data.valueOrNull, 42);
      expect(data, const AsyncData<int>(42));
      expect(data, isNot(const AsyncData<int>(43)));
    });

    test('AsyncError getters and equality', () {
      final StackTrace st = StackTrace.current;
      final AsyncState<int> error = AsyncError<int>('boom', st);
      expect(error.isLoading, isFalse);
      expect(error.hasData, isFalse);
      expect(error.hasError, isTrue);
      expect(error.valueOrNull, isNull);
      expect(error, AsyncError<int>('boom', st));
      expect(error, isNot(AsyncError<int>('other', st)));
    });

    test('when dispatches to the matching handler', () {
      const AsyncState<int> loading = AsyncLoading<int>(previousData: 7);
      const AsyncState<int> data = AsyncData<int>(1);
      final AsyncState<int> error = AsyncError<int>('e', StackTrace.current);

      expect(
        loading.when(
          loading: (int? p) => 'loading:$p',
          data: (int v) => 'data:$v',
          error: (Object e, StackTrace st) => 'error:$e',
        ),
        'loading:7',
      );
      expect(
        data.when(
          loading: (int? p) => 'loading:$p',
          data: (int v) => 'data:$v',
          error: (Object e, StackTrace st) => 'error:$e',
        ),
        'data:1',
      );
      expect(
        error.when(
          loading: (int? p) => 'loading:$p',
          data: (int v) => 'data:$v',
          error: (Object e, StackTrace st) => 'error:$e',
        ),
        'error:e',
      );
    });

    test('maybeWhen falls back to orElse for unhandled cases', () {
      const AsyncState<int> data = AsyncData<int>(5);
      final String result = data.maybeWhen(
        loading: (int? p) => 'loading',
        orElse: () => 'else',
      );
      expect(result, 'else');

      final String matched = data.maybeWhen(
        data: (int v) => 'data:$v',
        orElse: () => 'else',
      );
      expect(matched, 'data:5');
    });
  });
}
