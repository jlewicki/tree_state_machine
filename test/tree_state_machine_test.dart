import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_helpers.dart';

import 'fixture/data_tree.dart' as data_tree;
import 'fixture/flat_tree_1.dart' as flat_tree;
import 'fixture/tree_1.dart' as tree;
import 'fixture/tree_data.dart';

void main() {
  group('TreeStateMachine', () {
    group('forLeaves', () {
      test('should not be started when created', () {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        expect(sm.isStarted, equals(false));
      });

      test('should have no current state when created', () {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        expect(sm.currentState, equals(null));
      });

      test('should have transitions stream when created', () {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        expect(sm.transitions, isNotNull);
      });

      test('should throw for null leaves', () {
        expect(() => TreeStateMachine.forLeaves(null, flat_tree.r_1_key), throwsArgumentError);
      });

      test('should throw for null initial state', () {
        expect(() => TreeStateMachine.forLeaves(flat_tree.leaves, null), throwsArgumentError);
      });
    });

    group('start', () {
      test('should remain started if already started', () async {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        await sm.start();
        await sm.start();
        expect(sm.isStarted, isTrue);
      });

      test('should return same future when called more than once', () async {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        final future1 = sm.start();
        final future2 = sm.start();
        expect(future1, same(future2));
      });

      test('should set current state to initial state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());

        await sm.start();

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(tree.r_a_a_2_key));
      });

      test('should emit transition', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        final transitionsQ = StreamQueue(sm.transitions);

        final qItems = await Future.wait([transitionsQ.next, sm.start()]);

        final transition = qItems[0];
        expect(transition.from, equals(tree.r_key));
        expect(transition.to, equals(tree.r_a_a_2_key));
        expect(
          transition.traversed,
          orderedEquals([
            tree.r_key,
            tree.r_a_key,
            tree.r_a_a_key,
            tree.r_a_a_2_key,
          ]),
        );
      });

      test('should restart if stopped', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();
        await sm.stop();

        final transitionsQ = StreamQueue(sm.transitions);
        final qItems = await Future.wait([transitionsQ.next, sm.start()]);

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(tree.r_a_a_2_key));
        final transition = qItems[0];
        expect(transition.from, equals(tree.r_key));
        expect(transition.to, equals(tree.r_a_a_2_key));
      });
    });

    group('stop', () {
      test('should transition to Stopped state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        await sm.stop();

        expect(sm.isEnded, isTrue);
        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(StoppedTreeState.key));
      });

      test('should not dispatch message to current state', () async {
        var onMessageCalled = false;
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) {
            onMessageCalled = true;
            return ctx.unhandled();
          }
        }));
        await sm.start();

        await sm.stop();

        expect(sm.isEnded, isTrue);
        expect(onMessageCalled, isFalse);
      });

      test('should emit transition', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();
        final transitionsQ = StreamQueue(sm.transitions);

        final qItems = await Future.wait([transitionsQ.next, sm.stop()]);

        final transition = qItems[0];
        expect(transition.from, equals(tree.r_a_a_2_key));
        expect(transition.to, equals(StoppedTreeState.key));
      });

      test('should throw if not started', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        expect(() => sm.stop(), throwsStateError);
      });
    });

    group('dispose', () {
      test('should be disposed', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        sm.dispose();

        expect(sm.isDisposed, isTrue);
        expect(sm.isStarted, isFalse);
        expect(sm.isEnded, isFalse);
      });

      test('should close streams', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        final transitionsQ = StreamQueue(sm.transitions);
        final processedMessagesQ = StreamQueue(sm.processedMessages);
        final handledMessagesQ = StreamQueue(sm.handledMessages);
        final failedMessagesQ = StreamQueue(sm.failedMessages);
        await sm.start();

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

      test('should dispose data providers', () async {
        final r_provider = SpecialDataD.dataProvider();
        final r_a_provider = ImmutableData.dataProvider();
        final r_a_a_provider = LeafDataBase.dataProvider();
        final r_a_a_1_provider = LeafData1.dataProvider();
        final r_a_a_2_provider = LeafData2.dataProvider();
        final r_a_1_provider = ImmutableData.dataProvider();

        final sm = TestableTreeStateMachine(data_tree.treeBuilder(
          dataProviders: {
            data_tree.r_key: r_provider,
            data_tree.r_a_key: r_a_provider,
            data_tree.r_a_a_key: r_a_a_provider,
            data_tree.r_a_a_1_key: r_a_a_1_provider,
            data_tree.r_a_a_2_key: r_a_a_2_provider,
            data_tree.r_a_1_key: r_a_1_provider,
          },
        ));
        await sm.start();
        final qs = [
          StreamQueue(r_provider.dataStream),
          StreamQueue(r_a_provider.dataStream),
          StreamQueue(r_provider.dataStream),
          StreamQueue(r_a_a_provider.dataStream),
          StreamQueue(r_a_a_1_provider.dataStream),
          StreamQueue(r_a_a_2_provider.dataStream),
          StreamQueue(r_a_1_provider.dataStream),
        ];

        for (var node in sm.machine.nodes.values) {
          // For create of state and data providers
          node.node.state();
        }

        // Skip the 'current' value events that are immediately sent by BehaviorSubject on
        // subscription, since they are not important for this test.
        for (var q in qs) {
          await q.skip(1);
        }

        sm.dispose();

        for (var q in qs) {
          var hasNext = await q.hasNext;
          expect(hasNext, isFalse);
        }
      });

      test('should do nothing if already disposed', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder());
        await sm.start();
        sm.dispose();

        sm.dispose();

        expect(sm.isDisposed, isTrue);
      });
    });

    group('processMessage', () {
      test('should update current state key', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        await sm.start();

        await sm.currentState.sendMessage(Object());

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(tree.r_a_a_1_key));
      });

      test('should emit transition event after emitting processedMessage', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        await sm.start();
        await Timer(Duration(milliseconds: 1), () {});
        Object firstEvent;
        final nextProcessedMessage =
            StreamQueue(sm.processedMessages).next.then((pm) => firstEvent ??= pm);
        final nextTransition = StreamQueue(sm.transitions).next.then((t) => firstEvent ??= t);

        await sm.currentState.sendMessage(Object());
        await Future.any([nextProcessedMessage, nextTransition]);

        expect(firstEvent, isA<ProcessedMessage>());
      });

      test('should emit processedMessage event', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));
        await sm.start();
        final processedMessagesQ = StreamQueue(sm.processedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [processedMessagesQ.next, sm.currentState.sendMessage(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
      });

      test('should return FailedMessage if error is thrown in message handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final message = Object();
        final result = await sm.currentState.sendMessage(message);

        expect(result, isA<FailedMessage>());
        final error = result as FailedMessage;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should emit FailedMessage if error is thrown in entry handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final errorsQ = StreamQueue(sm.failedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, sm.currentState.sendMessage(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<FailedMessage>());
        final error = msgProcessed as FailedMessage;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should emit FailedMessage if error is thrown in exit handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(tree.treeBuilder(
          messageHandlers: {
            tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
          },
          exitHandlers: {
            tree.r_a_key: (ctx) => throw ex,
          },
        ));
        await sm.start();

        final errorsQ = StreamQueue(sm.failedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, sm.currentState.sendMessage(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<FailedMessage>());
        final error = msgProcessed as FailedMessage;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should emit FailedMessage if exception is thrown in onEnter handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(tree.treeBuilder(
          messageHandlers: {
            tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
          },
          entryHandlers: {
            tree.r_b_key: (ctx) => throw ex,
          },
        ));
        await sm.start();

        final errorsQ = StreamQueue(sm.failedMessages);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, sm.currentState.sendMessage(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<FailedMessage>());
        final error = msgProcessed as FailedMessage;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should keep current state if error is thrown in message handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final message = Object();
        final result = await sm.currentState.sendMessage(message);

        expect(result, isA<FailedMessage>());
        final error = result as FailedMessage;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should keep current state if error is thrown in transition handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine(tree.treeBuilder(
          messageHandlers: {
            tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_b_1_key),
          },
          entryHandlers: {
            tree.r_b_key: (ctx) => throw ex,
          },
        ));
        await sm.start();

        final message = Object();
        final result = await sm.currentState.sendMessage(message);

        expect(result, isA<FailedMessage>());
        final error = result as FailedMessage;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });
    });

    group('isEnded', () {
      test('should return false if state machine is not started', () {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));

        expect(sm.isEnded, isFalse);
      });

      test('should return false if current state is not final', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));
        await sm.start();

        expect(sm.isEnded, isFalse);
      });

      test('should return true if current state is final', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_X_key),
        }));
        await sm.start();

        await sm.currentState.sendMessage(Object());
        expect(sm.isEnded, isTrue);
      });
    });

    group('saveTo', () {
      test('should throw if sink is null', () {
        final sm = TreeStateMachine(tree.treeBuilder());
        expect(() => sm.saveTo(null), throwsArgumentError);
      });

      test('should throw if machine is not started', () {
        final sm = TreeStateMachine(tree.treeBuilder());
        expect(() => sm.saveTo(StreamController()), throwsStateError);
      });

      test('should write state data of active states to sink ', () async {
        final ioController = StreamController<List<int>>();
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        final results = await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.transform(utf8.decoder).transform(json.decoder).toList(),
        ]);
        final jsonList = results[1] as List<Object>;

        expect(jsonList.length, equals(1));
        expect(jsonList[0], isA<Map<String, dynamic>>());

        final encodableTree = EncodableTree.fromJson(jsonList[0]);
        expect(encodableTree.states, isNotNull);
        expect(
            encodableTree.states.map((s) => s.key),
            orderedEquals(
              sm.currentState.activeStates.map((s) => s.toString()),
            ));
      });
    });

    group('loadFrom', () {
      test('should throw if stream is null', () {
        final sm = TreeStateMachine(tree.treeBuilder());
        expect(() => sm.loadFrom(null), throwsArgumentError);
      });

      test('should throw if machine is started', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();
        expect(() => sm.loadFrom(StreamController<List<int>>().stream), throwsStateError);
      });

      test('should read active states from stream ', () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];
        sm = TreeStateMachine(tree.treeBuilder());

        await sm.loadFrom(Stream.fromIterable(encoded));

        expect(sm.isStarted, isTrue);
        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, tree.r_b_1_key);
      });

      test('should read active data states from stream ', () async {
        var sm = TreeStateMachine(data_tree.treeBuilder(initialDataValues: {
          tree.r_a_a_1_key: LeafData1()..counter = 10,
          tree.r_a_a_key: LeafDataBase()..name = 'Yo',
          tree.r_a_key: ImmutableData((b) => b
            ..name = 'Dude'
            ..price = 8),
          tree.r_key: SpecialDataD()
            ..playerName = 'FOO'
            ..startYear = 2000
            ..hiScores.add(HiScore()
              ..game = 'foo'
              ..score = 10),
        }));
        await sm.start(tree.r_a_a_1_key);

        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];
        sm = TreeStateMachine(data_tree.treeBuilder());

        await sm.loadFrom(Stream.fromIterable(encoded));

        expect(sm.isStarted, isTrue);
        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, tree.r_a_a_1_key);

        expect(sm.currentState.data(), isNotNull);
        expect(sm.currentState.data(), isA<LeafData1>());
        final r_a_a_1_data = sm.currentState.data<LeafData1>();
        expect(r_a_a_1_data.counter, equals(10));

        expect(sm.currentState.dataStream(tree.r_a_a_key).value, isNotNull);
        expect(sm.currentState.dataStream(tree.r_a_a_key).value, isA<LeafDataBase>());
        final r_a_a_data = sm.currentState.dataStream<LeafDataBase>(tree.r_a_a_key).value;
        expect(r_a_a_data.name, equals('Yo'));

        expect(sm.currentState.dataStream(tree.r_a_key).value, isNotNull);
        expect(sm.currentState.dataStream(tree.r_a_key).value, isA<ImmutableData>());
        final r_a_data = sm.currentState.dataStream<ImmutableData>(tree.r_a_key).value;
        expect(r_a_data.price, equals(8));
        expect(r_a_data.name, equals('Dude'));

        expect(sm.currentState.dataStream(tree.r_key).value, isNotNull);
        expect(sm.currentState.dataStream(tree.r_key).value, isA<SpecialDataD>());
        final rootData = sm.currentState.dataStream<SpecialDataD>(tree.r_key).value;
        expect(rootData.playerName, equals('FOO'));
        expect(rootData.startYear, equals(2000));
        expect(rootData.hiScores.length, equals(1));
        expect(rootData.hiScores[0].game, equals('foo'));
      });

      test('should throw if stream does not contain Map<string, dynamic>', () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        var byteStream = Stream.fromIterable(<Object>['A', 'B']).transform(json.fuse(utf8).encoder);

        expect(() async => await sm.loadFrom(byteStream), throwsArgumentError);
      });

      test('should throw if machine does not contain states from stream', () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];

        sm = TreeStateMachine(flat_tree.treeBuilder());
        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)), throwsStateError);
      });

      test(
          'should throw if active state path in stream is different from active state path in machine',
          () async {
        var sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];

        // Define another tree that shares keys but has a different shape
        final buildOtherTree = Root(
            key: tree.r_b_key,
            createState: (k) => EmptyTreeState(),
            initialChild: (_) => tree.r_key,
            children: [
              Interior(
                  key: tree.r_key,
                  createState: (k) => EmptyTreeState(),
                  initialChild: (_) => tree.r_b_1_key,
                  children: [Leaf(key: tree.r_b_1_key, createState: (k) => EmptyTreeState())])
            ]);

        sm = TreeStateMachine(buildOtherTree);

        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)), throwsStateError);
      });
    });

    test('should throw if stream has nodes thay are not in machine', () async {
      var sm = TreeStateMachine(tree.treeBuilder());
      await sm.start(tree.r_b_1_key);
      final ioController = StreamController<List<int>>();
      List<List<int>> encoded = (await Future.wait<Object>([
        sm.saveTo(ioController),
        ioController.stream.toList(),
      ]))[1];

      // Define another tree that shares keys but has a different shape
      final buildOtherTree = Root(
          key: tree.r_b_key,
          createState: (k) => EmptyTreeState(),
          initialChild: (_) => tree.r_b_1_key,
          children: [
            Leaf(key: tree.r_b_1_key, createState: (k) => EmptyTreeState()),
          ]);
      sm = TreeStateMachine(buildOtherTree);
      expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)), throwsStateError);
    });
  });

  group('CurrentState', () {
    group('key', () {
      test('should return initial state after starting', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.key, equals(tree.initialStateKey));
      });

      test('should return current state after transition', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.initialStateKey: (msgCtx) => msgCtx.goTo(tree.r_b_1_key),
        }));
        await sm.start();

        await sm.currentState.sendMessage(Object());

        expect(sm.currentState.key, equals(tree.r_b_1_key));
      });
    });

    group('sendMessage', () {
      test('should dispatch to state machine for processing', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.initialStateKey: (msgCtx) => msgCtx.stay(),
        }));
        await sm.start();

        var msg = Object();
        var result = await sm.currentState.sendMessage(msg);

        expect(result, isA<HandledMessage>());
        final handled = result as HandledMessage;
        expect(handled.message, same(msg));
        expect(handled.receivingState, equals(tree.r_a_a_2_key));
      });

      test('should throw if message is null', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(() => sm.currentState.sendMessage(null), throwsArgumentError);
      });

      test('should queue messages', () async {
        final msg1 = Object();
        final msg2 = Object();
        final msg3 = Object();
        final sm = TreeStateMachine(tree.treeBuilder(
          messageHandlers: {
            tree.r_a_a_2_key: (msgCtx) =>
                msgCtx.message == msg1 ? msgCtx.goTo(tree.r_a_a_1_key) : msgCtx.unhandled(),
            tree.r_a_a_1_key: (msgCtx) =>
                msgCtx.message == msg2 ? msgCtx.goTo(tree.r_b_1_key) : msgCtx.unhandled(),
            tree.r_b_1_key: (msgCtx) =>
                msgCtx.message == msg3 ? msgCtx.goTo(tree.r_b_2_key) : msgCtx.unhandled(),
          },
        ));
        await sm.start();

        final msg1Future = sm.currentState.sendMessage(msg1);
        final msg2Future = sm.currentState.sendMessage(msg2);
        final msg3Future = sm.currentState.sendMessage(msg3);

        await Future.wait([msg1Future, msg2Future, msg3Future]);
        expect(sm.currentState.key, equals(tree.r_b_2_key));

        var result = await msg1Future;
        expect(result, isA<HandledMessage>());
        var handled = result as HandledMessage;
        expect(handled.receivingState, equals(tree.r_a_a_2_key));
        expect(handled.transition.to, equals(tree.r_a_a_1_key));

        result = await msg2Future;
        expect(result, isA<HandledMessage>());
        handled = result as HandledMessage;
        expect(handled.receivingState, equals(tree.r_a_a_1_key));
        expect(handled.transition.to, equals(tree.r_b_1_key));

        result = await msg3Future;
        expect(result, isA<HandledMessage>());
        handled = result as HandledMessage;
        expect(handled.receivingState, equals(tree.r_b_1_key));
        expect(handled.transition.to, equals(tree.r_b_2_key));
      });
    });

    group('isActiveState', () {
      test('should return true for current state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.isActiveState(tree.initialStateKey), isTrue);
      });

      test('should return true for ancestor of current state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.isActiveState(tree.r_a_key), isTrue);
      });

      test('should return false for non-ancestor of current state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.isActiveState(tree.r_b_key), isFalse);
      });

      test('should throw if key is null', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(() => sm.currentState.isActiveState(null), throwsArgumentError);
      });
    });

    group('data', () {
      test('should return data from provider when available', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {data_tree.r_a_a_2_key: LeafData2()..label = 'cool'},
        ));
        await sm.start();

        final leafData = sm.currentState.data<LeafData2>();
        expect(leafData.label, equals('cool'));
      });

      test('should return data from state when available', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(tree.r_b_2_key);

        expect(sm.currentState.data<tree.ReadOnlyData>(), isNotNull);
        // 10 is what tree builer initializes counter to.
        expect(sm.currentState.data<tree.ReadOnlyData>().counter, equals(10));
      });

      test('should throw if data is a tree state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);

        expect(() => sm.currentState.data<DelegateState>(), throwsStateError);
      });

      test('should return null when data not available', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.data<tree.ReadOnlyData>(), isNull);
      });
    });

    group('activeData', () {
      test('should return data from owned provider when available', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_key: ImmutableData((b) => b
              ..name = 'foo'
              ..price = 10)
          },
        ));
        await sm.start();

        final r_a_data = sm.currentState.dataStream<ImmutableData>(data_tree.r_a_key).value;
        expect(r_a_data.name, equals('foo'));
        expect(r_a_data.price, equals(10));
      });

      test('should return data from leaf provider after transition.', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {data_tree.r_a_a_2_key: LeafData2()..label = 'cool'},
          messageHandlers: {
            data_tree.r_a_a_key: (ctx) => ctx.goTo(data_tree.r_a_a_1_key),
          },
        ));
        await sm.start();

        await sm.currentState.sendMessage(Object());

        final r_a_a_2_data = sm.currentState.data<LeafData1>();
        expect(r_a_a_2_data.counter, isNull);
      });
    });
  });
}
