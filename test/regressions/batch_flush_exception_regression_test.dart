import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:all_observer/all_observer.dart';

List<FlutterErrorDetails> _captureReportedErrors(void Function() run) {
  final List<FlutterErrorDetails> reported = <FlutterErrorDetails>[];
  final FlutterExceptionHandler? previous = FlutterError.onError;
  FlutterError.onError = reported.add;
  try {
    run();
  } finally {
    FlutterError.onError = previous;
  }
  return reported;
}

void main() {
  test('exception during flush does not keep stale callbacks queued', () {
    final Observable<int> throwing = Observable<int>(0);
    final Observable<int> second = Observable<int>(0);
    final Observable<int> third = Observable<int>(0);
    final Observable<int> unrelated = Observable<int>(0);
    final StateError error = StateError('flush failure');

    int throwingCalls = 0;
    int secondCalls = 0;
    int thirdCalls = 0;
    int unrelatedCalls = 0;

    throwing.listen((_) {
      throwingCalls++;
      throw error;
    });
    second.listen((_) {
      secondCalls++;
    });
    third.listen((_) {
      thirdCalls++;
    });
    unrelated.listen((_) {
      unrelatedCalls++;
    });

    final List<FlutterErrorDetails> reported = _captureReportedErrors(() {
      Observable.batch(() {
        throwing.value = 1;
        second.value = 1;
        third.value = 1;
      });
    });

    expect(reported, hasLength(1));
    expect(reported.single.exception, same(error));
    expect(throwingCalls, 1);
    expect(secondCalls, 1);
    expect(thirdCalls, 1);
    expect(unrelatedCalls, 0);

    unrelated.value = 1;

    expect(throwingCalls, 1);
    expect(secondCalls, 1);
    expect(thirdCalls, 1);
    expect(unrelatedCalls, 1);

    second.value = 2;

    expect(throwingCalls, 1);
    expect(secondCalls, 2);
    expect(thirdCalls, 1);
    expect(unrelatedCalls, 1);
  });
}
