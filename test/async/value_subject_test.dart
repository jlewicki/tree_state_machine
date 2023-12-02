import 'dart:async';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/async.dart';

void main() {
  group('ValueSubject', () {
    group('ctor', () {
      test('should be constructed without value', () {
        var subject = ValueSubject<int>();
        expect(subject.isBroadcast, isTrue);
        expect(subject.hasValue, isFalse);
        expect(subject.hasError, isFalse);
      });

      test('should be constructed with initial value', () {
        var subject = ValueSubject<int>.initialValue(2);
        expect(subject.isBroadcast, isTrue);
        expect(subject.hasValue, isTrue);
        expect(subject.value, 2);
        expect(subject.hasError, isFalse);
      });

      test('should be constructed with lazy value', () {
        var called = false;
        var subject = ValueSubject<int>.lazy(() {
          called = true;
          return 2;
        });
        expect(called, isFalse);

        expect(subject.isBroadcast, isTrue);
        expect(subject.hasValue, isTrue);
        expect(subject.value, 2);
        expect(subject.hasError, isFalse);
        expect(called, isTrue);
      });

      test('should notify listeners of initial value', () async {
        var subject = ValueSubject<int>.initialValue(2);
        var queue = StreamQueue<int>(subject);
        await expectLater(queue, emits(2));
      });

      test('constructs broadcast stream', () {
        var subject = ValueSubject<int>();
        expect(subject.isBroadcast, isTrue);

        subject = ValueSubject<int>.initialValue(2);
        expect(subject.isBroadcast, isTrue);
      });

      test('should not create lazy value if add is called before value', () {
        var called = false;
        var subject = ValueSubject<int>.lazy(() {
          called = true;
          return 2;
        });
        subject.add(1);
        expect(called, isFalse);
        expect(subject.hasValue, isTrue);
        expect(subject.value, 1);
      });
    });

    group('add', () {
      test('should update current value for stream', () {
        var subject = ValueSubject<int>.initialValue(2);
        subject.add(3);
        expect(subject.hasValue, true);
        expect(subject.value, 3);
      });

      test('should notify listeners of values', () async {
        var subject = ValueSubject<int>.initialValue(2);

        subject.add(3);
        var queue1 = StreamQueue<int>(subject);
        var queue2 = StreamQueue<int>(subject);
        await expectLater(queue1, emits(3));
        await expectLater(queue2, emits(3));
      });

      test('should notify listeners of errors', () async {
        var subject = ValueSubject<int>.initialValue(2);

        subject.addError('Oops');
        var queue = StreamQueue<int>(subject);
        await expectLater(queue, emitsError('Oops'));
      });

      test('should notify listeners when mapped', () async {
        var subject = ValueSubject<int>.initialValue(2);

        subject.add(3);
        var queue = StreamQueue<int>(subject.map((v) => v * 2));
        await expectLater(queue, emits(6));
      });
    });

    group('addStream', () {
      test('should update current value with values from from stream', () {
        var subject = ValueSubject<int>.initialValue(2);
        var stream = StreamController<int>(sync: true);
        subject.addStream(stream.stream);

        stream.add(1);
        expect(true, subject.hasValue);
        expect(1, subject.value);
      });

      test('should subscribe to stream immediately', () {
        var subject = ValueSubject<int>.initialValue(2, sync: true);
        var stream = ValueSubject<int>.initialValue(1, sync: true);
        subject.addStream(stream);

        expect(true, subject.hasValue);
        expect(1, subject.value);
      });

      test('should notify listeners of values from stream', () async {
        var subject = ValueSubject<int>.initialValue(2, sync: true);
        var stream = StreamController<int>(sync: true);
        subject.addStream(stream.stream);

        int? streamVal;
        subject.listen((value) {
          streamVal = value;
        });

        stream.add(1);
        expect(streamVal, 1);

        stream.add(3);
        expect(streamVal, 3);
      });

      test('should notify listeners of errors from stream', () async {
        var subject = ValueSubject<int>.initialValue(2, sync: true);
        var stream = StreamController<int>(sync: true);
        subject.addStream(stream.stream);

        Object? error;
        StackTrace? stackTrace;
        subject.listen(null, onError: (Object? e, StackTrace? st) {
          error = e;
          stackTrace = st as StackTrace;
        });

        var argError = ArgumentError('Oops');
        try {
          throw argError;
        } catch (e, st) {
          stream.addError(e, st);
        }

        expect(error, argError);
        expect(stackTrace, isNotNull);
      });
    });

    group('addError', () {
      test('should notify listeners', () async {
        var subject = ValueSubject<int>.initialValue(2);

        var error = 'oops';
        subject.addError(error);
        var queue1 = StreamQueue<int>(subject);
        var queue2 = StreamQueue<int>(subject);
        await expectLater(queue1, emitsError(error));
        await expectLater(queue2, emitsError(error));
      });

      test('should update current error for stream', () {
        var subject = ValueSubject<int>.initialValue(2);
        var e = 'oops';
        subject.addError(e);
        expect(subject.hasError, true);
        expect(subject.error.error, e);
      });
    });
  });
}
