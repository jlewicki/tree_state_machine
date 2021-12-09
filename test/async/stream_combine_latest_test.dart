import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/async.dart';

void main() {
  group('StreamCombineLatest', () {
    group('listen', () {
      test('should emit latest items whem all streams have emitted a value', () async {
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

        await Future.delayed(Duration(milliseconds: 100));

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

        combined.listen((values) => emittedValues = values, onError: (err) => error = err);

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

        await Future.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNotNull);
        expect(emittedValues, containsAllInOrder([3, 2, 1]));
        expect(error, equals('oops'));
      });

      test('should cancel immediately when a stream emits error and cancelOnError is true',
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

        await Future.delayed(Duration(milliseconds: 100));

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

        await Future.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNull);
        expect(isDone, isTrue);
      });
    });
  });
}
