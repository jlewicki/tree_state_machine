import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/async.dart';

void main() {
  group('StreamMerge', () {
    group('listen', () {
      test('should not emit until all streams have emitted a value', () async {
        var s1 = StreamController<int>.broadcast();
        var s2 = StreamController<int>.broadcast();
        var s3 = StreamController<int>.broadcast();
        var combined = StreamMerge([s1.stream, s2.stream, s3.stream]);

        var emittedValues = <int>[];
        var isDone = false;
        combined.listen(
          emittedValues.add,
          onDone: () => isDone = true,
        );

        Timer(Duration(milliseconds: 25), () {
          expect(emittedValues, isEmpty);
          s1.add(3);
          s1.close();
        });
        Timer(Duration(milliseconds: 50), () {
          expect(emittedValues, containsAllInOrder([3]));
          s2.add(2);
          s2.close();
        });
        Timer(Duration(milliseconds: 75), () {
          expect(emittedValues, containsAllInOrder([3, 2]));
          s3.add(1);
          s3.close();
        });

        await Future<void>.delayed(Duration(milliseconds: 100));

        expect(emittedValues, isNotNull);
        expect(emittedValues, containsAllInOrder([3, 2, 1]));
        expect(isDone, true);
      });
    });

    test('should emit error immediately when a stream emits error', () async {
      var s1 = StreamController<int>.broadcast();
      var s2 = StreamController<int>.broadcast();
      var s3 = StreamController<int>.broadcast();
      var combined = StreamMerge([s1.stream, s2.stream, s3.stream]);

      var emittedValues = <int>[];
      Object? error;
      var isDone = false;

      combined.listen(
        emittedValues.add,
        onError: (Object? err) => error = err,
        onDone: () => isDone = true,
      );

      Timer(Duration(milliseconds: 25), () {
        expect(emittedValues, isEmpty);
        expect(error, isNull);
        s1.add(3);
      });
      Timer(Duration(milliseconds: 50), () {
        expect(emittedValues, containsAllInOrder([3]));
        expect(error, isNull);
        s2.addError('oops');
        s2.add(2);
      });
      Timer(Duration(milliseconds: 75), () {
        expect(emittedValues, containsAllInOrder([3]));
        expect(error, equals('oops'));
        s3.add(1);
      });

      await Future<void>.delayed(Duration(milliseconds: 100));

      expect(emittedValues, isNotNull);
      expect(emittedValues, containsAllInOrder([3]));
      expect(error, equals('oops'));
      expect(isDone, isDone);
    });

    test(
        'should cancel immediately when a stream emits error and cancelOnError',
        () async {
      var s1 = StreamController<int>.broadcast();
      var s2 = StreamController<int>.broadcast();
      var s3 = StreamController<int>.broadcast();
      var combined = StreamMerge([s1.stream, s2.stream, s3.stream]);

      var emittedValues = <int>[];
      Object? error;
      var isDone = false;

      combined.listen(
        emittedValues.add,
        onError: (Object? err) => error = err,
        onDone: () => isDone = true,
        cancelOnError: true,
      );

      Timer(Duration(milliseconds: 25), () {
        expect(emittedValues, isEmpty);
        expect(error, isNull);
        s1.add(3);
      });
      Timer(Duration(milliseconds: 50), () {
        expect(emittedValues, containsAllInOrder([3]));
        expect(error, isNull);
        s2.addError('oops');
        s2.add(2);
      });
      Timer(Duration(milliseconds: 75), () {
        expect(emittedValues, containsAllInOrder([3]));
        expect(error, isNull);
        s3.add(1);
      });

      await Future<void>.delayed(Duration(milliseconds: 100));

      expect(emittedValues, isNotNull);
      expect(emittedValues, containsAllInOrder([3]));
      expect(error, isNull);
      expect(isDone, isDone);
    });

    test('should not complete until all input streams are complete', () async {
      Stream<int> createStream(List<int> vals,
          [Duration delay = Duration.zero]) async* {
        await Future<void>.delayed(delay);
        for (var val in vals) {
          yield val;
        }
      }

      var s1 = createStream([1]);
      var s2 = createStream([2, 4], Duration(milliseconds: 100));
      var s3 = createStream([3, 6, 9], Duration(milliseconds: 400));

      var combined = StreamMerge([s1, s2, s3]);

      var emitted = <int>[];
      var completer = Completer<void>();
      combined.listen(
        emitted.add,
        onDone: () => completer.complete(),
      );

      await completer.future;

      expect(emitted, isNotNull);
      expect(emitted, containsAllInOrder([1, 2, 4, 3, 6, 9]));
    });
  });
}
