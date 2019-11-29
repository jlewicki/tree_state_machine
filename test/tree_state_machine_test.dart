import 'dart:async';

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';
import 'tree_1.dart' as tree;
import 'flat_tree_1.dart' as flat_tree;

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
        expect(sm.currentState.key, equals(initialTransition.end));
      });

      test('should emit transition', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder());
        final transitionsQ = StreamQueue(sm.transitions);

        final qItems = await Future.wait([transitionsQ.next, sm.start()]);

        final transition = qItems[0] as Transition;
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

      test('current state should not change if exception is thrown in message handler', () async {
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
  });
}
