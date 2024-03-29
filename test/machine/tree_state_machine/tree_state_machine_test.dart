// ignore_for_file: non_constant_identifier_names

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/lifecycle.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import '../fixture/state_data.dart';
import '../fixture/tree.dart' as tree;
import '../fixture/data_tree.dart' as data_tree;
import '../fixture/flat_tree.dart' as flat_tree;

void main() {
  group('TreeStateMachine', () {
    group('processMessage', () {
      test('should update current state key', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        var currentState = await sm.start();

        await currentState.post(Object());

        expect(currentState.key, equals(tree.r_a_a_1_key));
      });

      test('should emit transition event after emitting processedMessage',
          () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        var currentState = await sm.start();
        await Future<void>.delayed(Duration.zero);
        Object? firstEvent;
        final nextProcessedMessage = StreamQueue(sm.processedMessages)
            .next
            .then((pm) => firstEvent ??= pm);
        final nextTransition =
            StreamQueue(sm.transitions).next.then((t) => firstEvent ??= t);

        await currentState.post(Object());
        await Future.any([nextProcessedMessage, nextTransition]);

        expect(firstEvent, isA<ProcessedMessage>());
      });

      test('should emit processedMessage event', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));
        var currentState = await sm.start();
        final processedMessagesQ = StreamQueue(sm.processedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [processedMessagesQ.next, currentState.post(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
      });

      test('should emit FailedMessage if error is thrown in message handler',
          () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
          tree.treeBuilder(
            messageHandlers: {
              tree.r_a_a_2_key: (ctx) => throw ex,
            },
          ),
          postMessageErrorPolicy: PostMessageErrorPolicy.convertToFailedMessage,
        );
        var currentState = await sm.start();

        final message = Object();
        final result = await currentState.post(message);

        expect(result, isA<FailedMessage>());
        final error = result as FailedMessage;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should emit FailedMessage if error is thrown in entry handler',
          () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
          tree.treeBuilder(
            messageHandlers: {
              tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
            },
            entryHandlers: {
              tree.r_b_key: (ctx) => throw ex,
            },
          ),
          postMessageErrorPolicy: PostMessageErrorPolicy.convertToFailedMessage,
        );
        var currentState = await sm.start();

        final errorsQ = StreamQueue(sm.failedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, currentState.post(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<FailedMessage>());
        final error = msgProcessed as FailedMessage;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should emit FailedMessage if error is thrown in exit handler',
          () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
          tree.treeBuilder(
            messageHandlers: {
              tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
            },
            exitHandlers: {
              tree.r_a_key: (ctx) => throw ex,
            },
          ),
          postMessageErrorPolicy: PostMessageErrorPolicy.convertToFailedMessage,
        );
        var currentState = await sm.start();

        final errorsQ = StreamQueue(sm.failedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, currentState.post(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<FailedMessage>());
        final error = msgProcessed as FailedMessage;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test(
          'should emit FailedMessage if exception is thrown in onEnter handler',
          () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
          tree.treeBuilder(
            messageHandlers: {
              tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
            },
            entryHandlers: {
              tree.r_b_key: (ctx) => throw ex,
            },
          ),
          postMessageErrorPolicy: PostMessageErrorPolicy.convertToFailedMessage,
        );
        var currentState = await sm.start();

        final errorsQ = StreamQueue(sm.failedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, currentState.post(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<FailedMessage>());
        final error = msgProcessed as FailedMessage;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should keep current state if error is thrown in message handler',
          () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
          tree.treeBuilder(messageHandlers: {
            tree.r_a_a_2_key: (ctx) => throw ex,
          }),
          postMessageErrorPolicy: PostMessageErrorPolicy.convertToFailedMessage,
        );
        var currentState = await sm.start();

        final message = Object();
        final result = await currentState.post(message);

        expect(result, isA<FailedMessage>());
        final error = result as FailedMessage;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should keep current state if error is thrown in transition handler',
          () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
          tree.treeBuilder(
            messageHandlers: {
              tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
            },
            entryHandlers: {
              tree.r_b_key: (ctx) => throw ex,
            },
          ),
          postMessageErrorPolicy: PostMessageErrorPolicy.convertToFailedMessage,
        );
        var currentState = await sm.start();

        final message = Object();
        final result = await currentState.post(message);

        expect(result, isA<FailedMessage>());
        final error = result as FailedMessage;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should rethrow error if policy says it should', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(
            tree.treeBuilder(messageHandlers: {
              tree.r_a_a_2_key: (ctx) => throw ex,
            }),
            postMessageErrorPolicy: PostMessageErrorPolicy.rethrowError);
        var currentState = await sm.start();

        final message = Object();
        expect(() => currentState.post(message), throwsA(same(ex)));
      });
    });

    group('isDone', () {
      test('should return false if state machine is not started', () {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));

        expect(sm.isDone, isFalse);
      });

      test('should return false if current state is not final', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));
        await sm.start();

        expect(sm.isDone, isFalse);
      });

      test('should return true if current state is final', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_X_key),
        }));
        var currentState = await sm.start();

        await currentState.post(Object());
        expect(currentState.key, equals(tree.r_X_key));
        expect(sm.isDone, isTrue);
      });

      test('should return true if current data state is final', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_XD_key: () => FinalData()..counter = 1
          },
          messageHandlers: {
            data_tree.r_a_a_2_key: (ctx) => ctx.goTo(data_tree.r_XD_key),
          },
        ));
        var currentState = await sm.start();

        await currentState.post(Object());
        expect(currentState.key, equals(data_tree.r_XD_key));
        expect(currentState.dataValue(data_tree.r_XD_key)!.counter, equals(1));
        expect(sm.isDone, isTrue);
      });
    });

    group('saveTo', () {
      test('should throw if machine is not started', () {
        final sm = TreeStateMachine(tree.treeBuilder());
        expect(() => sm.saveTo(StreamController()), throwsStateError);
      });

      test('should write state data of active states to sink ', () async {
        final ioController = StreamController<List<int>>();
        final sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start();

        final results = await Future.wait<Object?>([
          sm.saveTo(ioController),
          ioController.stream
              .transform(utf8.decoder)
              .transform(json.decoder)
              .toList(),
        ]);
        final jsonList = results[1] as List<Object?>;

        expect(jsonList.length, equals(1));
        expect(jsonList[0], isA<Map<String, dynamic>>());

        final encodableTree =
            EncodableTree.fromJson(jsonList[0] as Map<String, dynamic>);
        expect(encodableTree.states, isNotNull);
        expect(
            encodableTree.states.map((s) => s.key),
            orderedEquals(
              currentState.activeStates.map((s) => s.toString()),
            ));
      });
    });

    group('loadFrom', () {
      test('should throw if machine is started', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();
        expect(() => sm.loadFrom(StreamController<List<int>>().stream),
            throwsStateError);
      });

      test('should read active states from stream ', () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start(at: tree.r_b_1_key);
        var encoded = await _save(sm);
        sm = TreeStateMachine(tree.treeBuilder());

        await sm.loadFrom(Stream.fromIterable(encoded));

        expect(sm.lifecycle.isStarted, isTrue);
        expect(currentState, isNotNull);
        expect(currentState.key, tree.r_b_1_key);
      });

      test('should read active data states from stream ', () async {
        var sm = TreeStateMachine(data_tree.treeBuilder());
        var currentState = await sm.start(
            at: data_tree.r_a_a_1_key,
            withData: (b) => b
                .initialData(data_tree.r_a_a_1_key, LeafData1()..counter = 10)
                .initialData(data_tree.r_a_a_key, LeafDataBase()..name = 'Yo')
                .initialData(
                    data_tree.r_a_key, ImmutableData(name: 'Dude', price: 8))
                .initialData(
                    data_tree.r_key,
                    SpecialDataD()
                      ..playerName = 'FOO'
                      ..startYear = 2000
                      ..hiScores.add(HiScore('foo', 10))));

        var encoded = await _save(sm);
        sm = TreeStateMachine(data_tree.treeBuilder());

        await sm.loadFrom(Stream.fromIterable(encoded));
        expect(sm.lifecycle.isStarted, isTrue);
        expect(currentState.key, data_tree.r_a_a_1_key);

        final r_a_a_1_data = currentState.dataValue(data_tree.r_a_a_1_key);
        expect(r_a_a_1_data, isNotNull);
        expect(r_a_a_1_data!.counter, equals(10));

        final r_a_a_data = currentState.dataValue(data_tree.r_a_a_key);
        expect(r_a_a_data, isNotNull);
        expect(r_a_a_data!.name, equals('Yo'));

        final r_a_data = currentState.dataValue(data_tree.r_a_key);
        expect(r_a_data, isNotNull);
        expect(r_a_data!.price, equals(8));
        expect(r_a_data.name, equals('Dude'));

        final r_data = currentState.dataValue(data_tree.r_key);
        expect(r_data, isNotNull);
        expect(r_data!.playerName, equals('FOO'));
        expect(r_data.startYear, equals(2000));
        expect(r_data.hiScores.length, equals(1));
        expect(r_data.hiScores[0].game, equals('foo'));
      });

      test('should throw if stream does not contain Map<string, dynamic>',
          () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        var byteStream = Stream.fromIterable(<Object?>['A', 'B'])
            .transform(json.fuse(utf8).encoder);

        expect(() async => await sm.loadFrom(byteStream), throwsArgumentError);
      });

      test('should throw if machine does not contain states from stream',
          () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(at: tree.r_b_1_key);
        var encoded = await _save(sm);

        sm = TreeStateMachine(flat_tree.treeBuilder());
        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)),
            throwsStateError);
      });

      test(
          'should throw if active state path in stream is different from active state path in machine',
          () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(at: tree.r_b_1_key);
        var encoded = await _save(sm);

        // Define another tree that shares keys but has a different shape
        var otherTreeBuilder = StateTree.root(
          tree.r_b_key,
          InitialChild(tree.r_key),
          childStates: [
            State.composite(
              tree.r_key,
              InitialChild(tree.r_b_1_key),
              childStates: [State(tree.r_b_1_key)],
            )
          ],
        );

        sm = TreeStateMachine(otherTreeBuilder);

        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)),
            throwsStateError);
      });

      test('should throw if stream has nodes thay are not in machine',
          () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(at: tree.r_b_1_key);
        var encoded = await _save(sm);

        // Define another tree that shares keys but has a different shape
        var otherTreeBuilder = StateTree.root(
          tree.r_b_key,
          InitialChild(tree.r_b_1_key),
          childStates: [
            State(
              tree.r_b_1_key,
            )
          ],
        );

        sm = TreeStateMachine(otherTreeBuilder);
        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)),
            throwsStateError);
      });
    });

    group('start', () {
      test('should start in initial state', () async {
        var r_a_1_key = StateKey('r_a_1');

        var treeBuilder = StateTree(
          InitialChild(tree.r_b_key),
          childStates: [
            State(r_a_1_key),
            State(tree.r_b_key),
          ],
        );
        var sm = TreeStateMachine(treeBuilder);
        var cur = await sm.start();
        expect(cur.key, equals(tree.r_b_key));
      });

      test('should cause isStarting to return true before future completes',
          () async {
        var treeBuilder = StateTree(
          InitialChild(tree.r_a_key),
          childStates: [State(tree.r_a_key)],
        );
        var sm = TreeStateMachine(treeBuilder);
        var future = sm.start();
        expect(sm.lifecycle.isStarting, isTrue);
        await future;
        expect(sm.lifecycle.isStarting, isFalse);
        expect(sm.lifecycle.isStarted, isTrue);
      });

      test('should cause currentState have value when started', () async {
        var treeBuilder = StateTree(
          InitialChild(tree.r_a_key),
          childStates: [State(tree.r_a_key)],
        );
        var sm = TreeStateMachine(treeBuilder);
        var future = sm.start();
        expect(sm.currentState, isNull);
        await future;
        expect(sm.currentState, isNotNull);
      });
    });

    group('stop', () {
      test('should not complete streams', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        var transitionsDone = false;
        sm.transitions.listen((_) {}, onDone: () => transitionsDone = true);
        var processedMessagesDone = false;
        sm.processedMessages
            .listen((_) {}, onDone: () => processedMessagesDone = true);
        var handledMessagesDone = false;
        sm.handledMessages
            .listen((_) {}, onDone: () => handledMessagesDone = true);
        var failedMessagesDone = false;
        sm.failedMessages
            .listen((_) {}, onDone: () => failedMessagesDone = true);

        await sm.stop();

        //expect(sm.currentState, matcher)
        expect(transitionsDone, isFalse);
        expect(processedMessagesDone, isFalse);
        expect(handledMessagesDone, isFalse);
        expect(failedMessagesDone, isFalse);
      });
    });

    group('dispose', () {
      test('should be disposed', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        sm.dispose();

        expect(sm.lifecycle.isDisposed, isTrue);
        expect(sm.lifecycle.isStarted, isFalse);
        expect(sm.isDone, isFalse);
      });

      test('should close streams', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        final transitionsQ = StreamQueue(sm.transitions);
        final processedMessagesQ = StreamQueue(sm.processedMessages);
        final handledMessagesQ = StreamQueue(sm.handledMessages);
        final failedMessagesQ = StreamQueue(sm.failedMessages);

        sm.dispose();

        final hasNexts = await Future.wait([
          transitionsQ.hasNext,
          processedMessagesQ.hasNext,
          handledMessagesQ.hasNext,
          failedMessagesQ.hasNext,
        ]);

        for (var hasNext in hasNexts) {
          expect(hasNext, isFalse);
        }
      });

      test('should complete streams when state machine is disposed', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder());
        await sm.start();

        var closedByKey = <StateKey, bool>{};
        sm.dataStream<ImmutableData>(data_tree.r_a_key).listen(
              null,
              onDone: () => closedByKey[data_tree.r_a_key] = true,
            );
        sm.dataStream<LeafDataBase>(data_tree.r_a_a_key).listen(
              null,
              onDone: () => closedByKey[data_tree.r_a_a_key] = true,
            );
        sm.dataStream<LeafData1>(data_tree.r_a_a_1_key).listen(
              null,
              onDone: () => closedByKey[data_tree.r_a_a_1_key] = true,
            );

        sm.dispose();

        await Future<void>.delayed(Duration(milliseconds: 10));

        expect(closedByKey[data_tree.r_a_key], isTrue);
      });

      test('should close DataValues for data states', () async {
        var sm = TestableTreeStateMachine(data_tree.treeBuilder());
        var doneByKey = <StateKey, bool>{};
        await sm.start();
        for (var mn in sm.machine.nodes.values) {
          if (mn.data != null) {
            mn.data!.listen((value) {}, onDone: () {
              doneByKey[mn.key] = true;
            });
          }
        }

        sm.dispose();

        // Yield so that the DataValue listeners will be notified of stream completion.
        await Future<void>.delayed(Duration.zero);
        // Now we can make sure we were notified of completion
        for (var mn in sm.machine.nodes.values) {
          if (mn.data != null) {
            expect(doneByKey[mn.key], isTrue);
          }
        }
      });

      test('should do nothing if already disposed', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder());
        await sm.start();
        sm.dispose();

        sm.dispose();

        expect(sm.lifecycle.isDisposed, isTrue);
      });

      test('should complete when disposed', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        var disposedFuture =
            sm.lifecycle.firstWhere((s) => s == LifecycleState.disposed);
        sm.dispose();
        await disposedFuture;

        expect(sm.lifecycle.isDisposed, isTrue);
        expect(sm.lifecycle.isStarted, isFalse);
        expect(sm.isDone, isFalse);
      });

      test('should complete if subscribe happens after disposal', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        var disposedFuture =
            sm.lifecycle.firstWhere((s) => s == LifecycleState.disposed);
        sm.dispose();
        await disposedFuture;

        expect(sm.lifecycle.isDisposed, isTrue);
        expect(sm.lifecycle.isStarted, isFalse);
        expect(sm.isDone, isFalse);
      });

      test('should cause currentState to be null when disposed', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();
        expect(sm.currentState, isNotNull);
        sm.dispose();
        expect(sm.currentState, isNull);
      });
    });

    group('lifecycle', () {
      test('runthrough', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        expect(sm.lifecycle.isConstructed, isTrue);

        var startFuture = sm.start();
        expect(sm.lifecycle.isStarting, isTrue);

        await startFuture;
        expect(sm.lifecycle.isStarted, isTrue);

        var stopFuture = sm.stop();
        expect(sm.lifecycle.isStopping, isTrue);

        await stopFuture;
        expect(sm.lifecycle.isStopped, isTrue);

        sm.dispose();
        expect(sm.lifecycle.isDisposed, isTrue);
      });
    });

    group('rootNode', () {
      test('should return populated root node', () {
        var declBuilder = tree.treeBuilder();
        var context = TreeBuildContext();
        StateTreeBuilder(declBuilder).build(context);
        var expectedNodes = context.nodes;

        final sm = TreeStateMachine(declBuilder);
        expect(sm.rootNode, isNotNull);

        var states = sm.rootNode.selfAndDescendants().map((e) => e.key).toSet();
        expect(states, containsAll(expectedNodes.keys));
      });
    });
  });
}

Future<List<List<int>>> _save(TreeStateMachine sm) async {
  final ioController = StreamController<List<int>>();
  return (await Future.wait([
    sm.saveTo(ioController),
    ioController.stream.toList(),
  ]))[1] as List<List<int>>;
}
