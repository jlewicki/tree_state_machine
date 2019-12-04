import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';
import 'fixture/tree_1.dart' as tree;
import 'fixture/flat_tree_1.dart' as flat_tree;
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

      test('should be constructed with null root', () {
        expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
      });
    });

    group('start', () {
      test('should throw when already started', () async {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        await sm.start();
        expect(() async => sm.start(), throwsStateError);
      });

      test('should set current state to initial state', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());

        final initialTransition = await sm.start();

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(tree.r_a_a_2_key));
        expect(sm.currentState.key, equals(initialTransition.to));
      });

      test('should emit transition', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
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
    });

    group('processMessage', () {
      test('should update current state key', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        await sm.start();

        await sm.currentState.sendMessage(Object());

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(tree.r_a_a_1_key));
      });

      test('should emit transition event after emitting processedMessage', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
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

        expect(firstEvent, isA<MessageProcessed>());
      });

      test('should emit processedMessage event', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
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

      test('should return ProcessingError if exception is thrown in message handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final message = Object();
        final result = await sm.currentState.sendMessage(message);

        expect(result, isA<ProcessingError>());
        final error = result as ProcessingError;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should emit ProcessingError if exception is thrown in message handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final errorsQ = StreamQueue(sm.errors);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, sm.currentState.sendMessage(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<ProcessingError>());
        final error = msgProcessed as ProcessingError;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should emit ProcessingError if exception is thrown in transition handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final errorsQ = StreamQueue(sm.errors);

        final msg = Object();
        final qItems = await Future.wait(
          [errorsQ.next, sm.currentState.sendMessage(msg)],
        );

        final msgProcessed = qItems[0];
        expect(msgProcessed.receivingState, equals(tree.r_a_a_2_key));
        expect(msgProcessed.message, same(msg));
        expect(msgProcessed, isA<ProcessingError>());
        final error = msgProcessed as ProcessingError;
        expect(error.error, same(ex));
        expect(error.stackTrace, isNotNull);
      });

      test('should keep current state if exception is thrown in message handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => throw ex,
        }));
        await sm.start();

        final message = Object();
        final result = await sm.currentState.sendMessage(message);

        expect(result, isA<ProcessingError>());
        final error = result as ProcessingError;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });

      test('should keep current state if exception is thrown in transition handler', () async {
        final ex = Exception('oops');
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(
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

        expect(result, isA<ProcessingError>());
        final error = result as ProcessingError;
        expect(error.message, same(message));
        expect(error.receivingState, equals(tree.r_a_a_2_key));
        expect(error.error, same(ex));
      });
    });

    group('isEnded', () {
      test('should return false if state machine is not started', () {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));

        expect(sm.isEnded, isFalse);
      });

      test('should return false if current state is not final', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          // This processes message, but does not result in a transition
          tree.r_a_a_2_key: (ctx) => ctx.stay(),
        }));
        await sm.start();

        expect(sm.isEnded, isFalse);
      });

      test('should return true if current state is final', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
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
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        expect(() => sm.saveTo(null), throwsArgumentError);
      });

      test('should throw if machine is not started', () {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        expect(() => sm.saveTo(StreamController()), throwsStateError);
      });

      test('should write state data of active states to sink ', () async {
        final ioController = StreamController<List<int>>();
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
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
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        expect(() => sm.loadFrom(null), throwsArgumentError);
      });

      test('should throw if machine is started', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();
        expect(() => sm.loadFrom(StreamController<List<int>>().stream), throwsStateError);
      });

      test('should read active states from stream ', () async {
        var sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];
        sm = TreeStateMachine.forRoot(tree.treeBuilder());

        await sm.loadFrom(Stream.fromIterable(encoded));

        expect(sm.isStarted, isTrue);
        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, tree.r_b_1_key);
      });

      test('should read active data states from stream ', () async {
        var sm = TreeStateMachine.forRoot(tree.dataTreeBuilder());
        await sm.start(tree.r_a_a_1_key);
        final r_a_a_1_data = sm.currentState.data<SimpleDataC>();
        r_a_a_1_data.modelYear = '101';
        final r_a_a_data = sm.currentState.activeData<SimpleDataB>(tree.r_a_a_key);
        r_a_a_data.productNumber = 'XYZ';
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];
        sm = TreeStateMachine.forRoot(tree.dataTreeBuilder());

        await sm.loadFrom(Stream.fromIterable(encoded));

        expect(sm.isStarted, isTrue);
        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, tree.r_a_a_1_key);
        expect(sm.currentState.data(), isNotNull);
        expect(sm.currentState.data(), isA<SimpleDataC>());
        expect(sm.currentState.data<SimpleDataC>().modelYear, equals('101'));
        expect(sm.currentState.activeData(tree.r_a_a_key), isNotNull);
        expect(sm.currentState.activeData(tree.r_a_a_key), isA<SimpleDataB>());
        expect(
          sm.currentState.activeData<SimpleDataB>(tree.r_a_a_key).productNumber,
          equals('XYZ'),
        );
      });

      test('should throw if stream does not contain Map<string, dynamic>', () async {
        var sm = TreeStateMachine.forRoot(tree.treeBuilder());
        var byteStream = Stream.fromIterable(<Object>['A', 'B']).transform(json.fuse(utf8).encoder);

        expect(() async => await sm.loadFrom(byteStream), throwsArgumentError);
      });

      test('should throw if machine does not contain states from stream', () async {
        var sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];

        sm = TreeStateMachine.forRoot(flat_tree.treeBuilder());
        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)), throwsStateError);
      });

      test(
          'should throw if active state path in stream is different from active state path in machine',
          () async {
        var sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start(tree.r_b_1_key);
        final ioController = StreamController<List<int>>();
        List<List<int>> encoded = (await Future.wait<Object>([
          sm.saveTo(ioController),
          ioController.stream.toList(),
        ]))[1];

        // Define another tree that shares keys but has a different shape
        final buildOtherTree = rootBuilder(
            key: tree.r_b_key,
            createState: (k) => EmptyTreeState(),
            initialChild: (_) => tree.r_key,
            children: [
              interiorBuilder(
                  key: tree.r_key,
                  state: (k) => EmptyTreeState(),
                  initialChild: (_) => tree.r_b_1_key,
                  children: [
                    leafBuilder(key: tree.r_b_1_key, createState: (k) => EmptyTreeState())
                  ])
            ]);

        sm = TreeStateMachine.forRoot(buildOtherTree);

        expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)), throwsStateError);
      });
    });

    test('should throw if stream has nodes thay are not in machine', () async {
      var sm = TreeStateMachine.forRoot(tree.treeBuilder());
      await sm.start(tree.r_b_1_key);
      final ioController = StreamController<List<int>>();
      List<List<int>> encoded = (await Future.wait<Object>([
        sm.saveTo(ioController),
        ioController.stream.toList(),
      ]))[1];

      // Define another tree that shares keys but has a different shape
      final buildOtherTree = rootBuilder(
          key: tree.r_b_key,
          createState: (k) => EmptyTreeState(),
          initialChild: (_) => tree.r_b_1_key,
          children: [
            leafBuilder(key: tree.r_b_1_key, createState: (k) => EmptyTreeState()),
          ]);
      sm = TreeStateMachine.forRoot(buildOtherTree);
      expect(() async => await sm.loadFrom(Stream.fromIterable(encoded)), throwsStateError);
    });
  });

  group('CurrentState', () {
    group('key', () {
      test('should return initial state after starting', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.key, equals(tree.initialStateKey));
      });

      test('should return current state after transition', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.initialStateKey: (msgCtx) => msgCtx.goTo(tree.r_b_1_key),
        }));
        await sm.start();

        await sm.currentState.sendMessage(Object());

        expect(sm.currentState.key, equals(tree.r_b_1_key));
      });
    });

    group('sendMessage', () {
      test('should dispatch to state machine for processing', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
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
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();

        expect(() => sm.currentState.sendMessage(null), throwsArgumentError);
      });
    });

    group('isActiveState', () {
      test('should return true for current state', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.isActiveState(tree.initialStateKey), isTrue);
      });

      test('should return true for ancestor of current state', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.isActiveState(tree.r_a_key), isTrue);
      });

      test('should return false for non-ancestor of current state', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();

        expect(sm.currentState.isActiveState(tree.r_b_key), isFalse);
      });

      test('should throw if key is null', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        await sm.start();

        expect(() => sm.currentState.isActiveState(null), throwsArgumentError);
      });
    });

    group('data', () {
      test('shoud return data from provider when available', () {});

      test('shoud return data from state when available', () {});

      test('shoud return null when data not available', () {});
    });
  });
}
