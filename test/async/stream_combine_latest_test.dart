import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/async.dart';

void main() {
  group('StreamCombineLatest', () {
    group('listen', () {
      test('should emit latest items', () async {
        Stream<int> createStream(List<int> vals) async* {
          for (var val in vals) {
            yield val;
          }
        }

        var s1 = createStream([3, 1, 2]);
        var s2 = createStream([2, 2]);
        var s3 = createStream([1, 3]);

        var combined = StreamCombineLatest([s1, s2, s3]);

        List<(int, int, int)>? emittedValues = [];

        var completer = Completer<void>();
        combined.listen(
          (values) => emittedValues.add((values[0], values[1], values[2])),
          onDone: () => completer.complete(),
        );

        await completer.future;

        expect(emittedValues, isNotNull);
        expect(emittedValues, containsAllInOrder([(3, 2, 1), ((1, 2, 3))]));
      });

      test('should not emit until all streams have emitted a value', () async {
        var s1 = StreamController<int>.broadcast();
        var s2 = StreamController<int>.broadcast();
        var s3 = StreamController<int>.broadcast();
        var combined = StreamCombineLatest([s1.stream, s2.stream, s3.stream]);

        List<int>? emittedValues;

        combined.listen((values) => emittedValues = values);

        Timer(Duration(milliseconds: 25), () {
          expect(emittedValues, isNull);
          s1.add(3);
        });
        Timer(Duration(milliseconds: 50), () {
          expect(emittedValues, isNull);
          s2.add(2);
        });
        Timer(Duration(milliseconds: 75), () {
          expect(emittedValues, isNull);
          s3.add(1);
        });

        await Future<void>.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNotNull);
        expect(emittedValues, containsAllInOrder([3, 2, 1]));
      });

      test('should emit error immediately when a stream emits error', () async {
        var s1 = StreamController<int>.broadcast();
        var s2 = StreamController<int>.broadcast();
        var s3 = StreamController<int>.broadcast();
        var combined = StreamCombineLatest([s1.stream, s2.stream, s3.stream]);

        List<int>? emittedValues;
        Object? error;

        combined.listen(
          (values) => emittedValues = values,
          onError: (Object? err) => error = err,
        );

        Timer(Duration(milliseconds: 25), () {
          expect(emittedValues, isNull);
          expect(error, isNull);
          s1.add(3);
        });
        Timer(Duration(milliseconds: 50), () {
          expect(emittedValues, isNull);
          expect(error, isNull);
          s2.addError('oops');
          s2.add(2);
        });
        Timer(Duration(milliseconds: 75), () {
          expect(emittedValues, isNull);
          expect(error, equals('oops'));
          s3.add(1);
        });

        await Future<void>.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNotNull);
        expect(emittedValues, containsAllInOrder([3, 2, 1]));
        expect(error, equals('oops'));
      });

      test(
          'should cancel immediately when a stream emits error and cancelOnError is true',
          () async {
        var s1 = StreamController<int>.broadcast();
        var s2 = StreamController<int>.broadcast();
        var s3 = StreamController<int>.broadcast();
        var combined = StreamCombineLatest([s1.stream, s2.stream, s3.stream]);

        List<int>? emittedValues;
        Object? error;

        combined.listen(
          (values) => emittedValues = values,
          onError: (Object err) => error = err,
          cancelOnError: true,
        );

        Timer(Duration(milliseconds: 25), () {
          expect(emittedValues, isNull);
          expect(error, isNull);
          s1.add(3);
        });
        Timer(Duration(milliseconds: 50), () {
          expect(emittedValues, isNull);
          expect(error, isNull);
          s2.addError('oops');
          s2.add(2);
        });
        Timer(Duration(milliseconds: 75), () {
          expect(emittedValues, isNull);
          expect(error, equals('oops'));
          s3.add(1);
        });

        await Future<void>.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNull);
        expect(error, equals('oops'));
      });

      test('should emit done when any stream is done', () async {
        var s1 = StreamController<int>.broadcast();
        var s2 = StreamController<int>.broadcast();
        var s3 = StreamController<int>.broadcast();
        var combined = StreamCombineLatest([s1.stream, s2.stream, s3.stream]);

        List<int>? emittedValues;
        var isDone = false;

        combined.listen(
          (values) => emittedValues = values,
          onDone: () => isDone = true,
        );

        Timer(Duration(milliseconds: 25), () {
          expect(emittedValues, isNull);
          s1.add(3);
        });
        Timer(Duration(milliseconds: 50), () {
          expect(emittedValues, isNull);
          s2.close();
        });
        Timer(Duration(milliseconds: 75), () {
          expect(emittedValues, isNull);
          expect(isDone, isTrue);
          s3.add(1);
        });

        await Future<void>.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNull);
        expect(isDone, isTrue);
      });
    });
  });
}
