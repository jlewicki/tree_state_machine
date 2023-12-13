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
        var subject = ValueSubject.initialValue(2);
        var e = 'oops';
        subject.addError(e);
        expect(subject.hasError, isTrue);
        expect(subject.error.error, equals(e));
      });
    });

    group('mapValueStream', () {
      test('should produce mapped value synchronously', () {
        var subject = ValueSubject.initialValue(2);
        var mapped = subject.mapValueStream((value) => value * 2);
        expect(mapped.hasValue, isTrue);
        expect(mapped.value, equals(4));
      });

      test('should notify listeners of values async', () async {
        var subject = ValueSubject.initialValue(2);
        var mapped = subject.mapValueStream((value) => value * 2);

        // Because the subject will notify listeners (i.e. the mapped subject) asynchronously,
        // these values will not be mapped until an await occurs
        subject.add(3);
        subject.add(4);
        subject.add(5);

        // values added in lines above is not mapped until the thread yields
        expect(mapped.value, equals(4));

        var [items1, items2] = await Future.wait([
          StreamQueue(mapped).lookAhead(4),
          StreamQueue(mapped).lookAhead(4),
        ]);
        expect(items1, equals([4, 6, 8, 10]));
        expect(items2, equals([4, 6, 8, 10]));
      });

      test('should notify listeners of values sync', () async {
        var subject = ValueSubject.initialValue(2, sync: true);
        var mapped = subject.mapValueStream((value) => value * 2);

        // Because the subject will notify listeners (i.e. the mapped subject) synchronously,
        // these values will be mapped immediately
        subject.add(3);
        subject.add(4);
        subject.add(5);

        // values added in line above are mapped immediately, so the last one wins
        expect(mapped.value, equals(10));

        var [items1, items2] = await Future.wait([
          StreamQueue(mapped).lookAhead(1),
          StreamQueue(mapped).lookAhead(1),
        ]);
        expect(items1, equals([10]));
        expect(items2, equals([10]));
      });

      test('should convert errors in mapping function to error notifications ', () {
        var subject = ValueSubject.initialValue(2);
        var error = ArgumentError("oops");
        var mapped = subject.mapValueStream((value) => throw error);
        expect(mapped.hasError, isTrue);
        expect(mapped.error.error, equals(error));
      });
    });
  });
}
