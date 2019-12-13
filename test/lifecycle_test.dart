import 'package:test/test.dart';
import 'package:tree_state_machine/src/lifecycle.dart';

final isDisposedError = TypeMatcher<DisposedError>();
final Matcher throwsDisposedError = throwsA(isDisposedError);
Future doStart() => Future.delayed(Duration(milliseconds: 100));
Future doStop() => Future.delayed(Duration(milliseconds: 100));

void main() {
  group('Lifecycle', () {
    Lifecycle lifecycle({
      Future Function() doStart,
      Future Function() doStop,
      void Function() doDispose,
    }) =>
        Lifecycle(
          doDispose ?? () {},
        );

    group('start', () {
      test('should be starting before future completes', () async {
        final l = lifecycle();
        l.start(doStart);
        expect(l.isStarting, isTrue);
      });

      test('should be started after future completes when new', () async {
        final l = lifecycle();
        await l.start(doStart);
        expect(l.isStarted, isTrue);
      });

      test('should be started after future completes when starting', () async {
        final l = lifecycle();
        l.start(doStart);

        await l.start(doStart);
        expect(l.isStarted, isTrue);
      });

      test('should be started after future completes when started', () async {
        final l = lifecycle();
        await l.start(doStart);

        await l.start(doStart);
        expect(l.isStarted, isTrue);
      });

      test('should be started after future completes when stopping', () async {
        final l = lifecycle();
        await l.start(doStart);
        l.stop(doStop);

        await l.start(doStart);
        expect(l.isStarted, isTrue);
      });

      test('should be started after future completes when stopped', () async {
        final l = lifecycle();
        await l.start(doStart);
        await l.stop(doStart);

        await l.start(doStop);
        expect(l.isStarted, isTrue);
      });

      test('should throw error when disposed', () async {
        final l = lifecycle();
        l.dispose();

        expect(() => l.start(doStart), throwsDisposedError);
      });

      test('should return same future if called more than once', () async {
        final l = lifecycle();
        final f1 = l.start(doStart);
        final f2 = l.start(doStart);
        final f3 = l.start(doStart);
        expect(f1, same(f2));
        expect(f1, same(f3));
      });

      test('all futures should complete if called more than once', () async {
        final l = lifecycle();
        final f1 = l.start(doStart);
        final f2 = l.start(doStart);
        final f3 = l.start(doStart);

        await Future.wait([f1, f2, f3]);
        expect(l.isStarted, isTrue);
      });

      test('should call doStart callback', () async {
        var startCount = 0;
        final l = lifecycle();
        await l.start(() async {
          startCount += 1;
        });
        expect(startCount, equals(1));
      });

      test('should call doStart callback only once if called more than once', () async {
        var startCount = 0;
        Future doStart() async {
          startCount += 1;
        }

        final l = lifecycle();
        l.start(doStart);
        l.start(doStart);
        await l.start(doStart);
        expect(startCount, equals(1));
      });
    });

    group('stop', () {
      test('should be stopping before future completes', () async {
        final l = lifecycle();
        await l.start(doStart);

        l.stop(doStop);

        expect(l.isStopping, isTrue);
      });

      test('should be stopped after future completes when starting', () async {
        final l = lifecycle();
        l.start(doStart);

        await l.stop(doStop);

        expect(l.isStopped, isTrue);
      });

      test('should be stopped after future completes when started', () async {
        final l = lifecycle();
        await l.start(doStart);

        await l.stop(doStop);

        expect(l.isStopped, isTrue);
      });

      test('should be stopped after future completes when stopping', () async {
        final l = lifecycle();
        await l.start(doStart);
        l.stop(doStop);

        await l.stop(doStop);

        expect(l.isStopped, isTrue);
      });

      test('should be stopped after future completes when stopped', () async {
        final l = lifecycle();
        await l.start(doStart);
        await l.stop(doStop);

        await l.stop(doStop);

        expect(l.isStopped, isTrue);
      });

      test('should yield error when disposed', () async {
        final l = lifecycle();
        l.dispose();

        expect(() => l.stop(doStart), throwsDisposedError);
      });

      test('should return same future if called more than once', () async {
        final l = lifecycle();
        await l.start(doStart);

        final f1 = l.stop(doStop);
        final f2 = l.stop(doStop);
        final f3 = l.stop(doStop);
        expect(f1, same(f2));
        expect(f1, same(f3));
      });

      test('all futures should complete if called more than once', () async {
        final l = lifecycle();
        await l.start(doStart);

        final f1 = l.stop(doStop);
        final f2 = l.stop(doStop);
        final f3 = l.stop(doStop);

        await Future.wait([f1, f2, f3]);
        expect(l.isStopped, isTrue);
      });

      test('should call doStop callback', () async {
        var stopCount = 0;
        final l = lifecycle();
        await l.start(doStart);

        await l.stop(() async {
          stopCount += 1;
        });
        expect(stopCount, equals(1));
      });

      test('should call doStop callback only once if called more than once', () async {
        var stopCount = 0;
        Future doStop() async {
          stopCount += 1;
        }

        final l = lifecycle();
        await l.start(doStart);

        l.stop(doStop);
        l.stop(doStop);
        await l.stop(doStop);

        expect(stopCount, equals(1));
      });
    });

    group('dispose', () {
      test('should be disposed when new', () async {
        final l = lifecycle();

        l.dispose();

        expect(l.isDisposed, isTrue);
      });

      test('should be disposed when started', () async {
        final l = lifecycle();
        await l.start(doStart);

        l.dispose();

        expect(l.isDisposed, isTrue);
      });

      test('should be disposed when stopping', () async {
        final l = lifecycle();
        await l.start(doStart);
        l.stop(doStop);

        l.dispose();

        expect(l.isDisposed, isTrue);
      });

      test('should be disposed when stopped', () async {
        final l = lifecycle();
        await l.start(doStart);
        await l.stop(doStop);

        l.dispose();

        expect(l.isDisposed, isTrue);
      });

      test('should call doDispose callback', () async {
        var disposeCount = 0;
        final l = lifecycle(doDispose: () {
          disposeCount += 1;
        });
        await l.start(doStart);

        l.dispose();
        expect(disposeCount, equals(1));
      });

      test('should call doDispose callback only once if called more than once', () async {
        var disposeCount = 0;
        final l = lifecycle(doDispose: () {
          disposeCount += 1;
        });
        await l.start(doStart);

        l.dispose();
        l.dispose();
        l.dispose();
        expect(disposeCount, equals(1));
      });
    });
  });
}
