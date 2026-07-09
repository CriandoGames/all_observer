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

    test('maybeWhen dispatches loading, data and error handlers', () {
      const AsyncState<int> loading = AsyncLoading<int>(previousData: 3);
      const AsyncState<int> data = AsyncData<int>(7);
      final StackTrace stackTrace = StackTrace.current;
      final AsyncState<int> error = AsyncError<int>('boom', stackTrace);

      expect(
        loading.maybeWhen(
          loading: (int? previous) => 'loading:$previous',
          orElse: () => 'else',
        ),
        'loading:3',
      );
      expect(
        data.maybeWhen(
          data: (int value) => 'data:$value',
          orElse: () => 'else',
        ),
        'data:7',
      );
      expect(
        error.maybeWhen(
          error: (Object value, StackTrace trace) =>
              'error:$value:${identical(trace, stackTrace)}',
          orElse: () => 'else',
        ),
        'error:boom:true',
      );
    });

    test('equal states have equal hash codes and stable diagnostics', () {
      final StackTrace stackTrace = StackTrace.fromString('test trace');
      const AsyncLoading<int> loading = AsyncLoading<int>(previousData: 1);
      const AsyncData<int> data = AsyncData<int>(42);
      final AsyncError<int> error = AsyncError<int>('boom', stackTrace);

      expect(
        loading.hashCode,
        const AsyncLoading<int>(previousData: 1).hashCode,
      );
      expect(data.hashCode, const AsyncData<int>(42).hashCode);
      expect(error.hashCode, AsyncError<int>('boom', stackTrace).hashCode);

      expect(loading.toString(), contains('previousData: 1'));
      expect(data.toString(), contains('42'));
      expect(error.toString(), contains('boom'));
    });

    test('AsyncValue is a plain alias for AsyncState', () {
      const AsyncValue<int> value = AsyncData<int>(1);
      expect(value, isA<AsyncState<int>>());
      expect(value, const AsyncData<int>(1));
    });
  });
}
