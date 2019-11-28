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
      test('should update current state', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        await sm.start();
        final currentState = sm.currentState;

        await sm.currentState.sendMessage(Object());

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(tree.r_a_a_1_key));
        expect(sm.currentState, predicate((cs) => !identical(cs, currentState)));
      });

      test('should emit transition after emitting processedMessage', () async {
        final sm = TreeStateMachine.forRoot(tree.treeBuilder(messageHandlers: {
          tree.r_a_a_2_key: (ctx) => ctx.goTo(tree.r_a_a_1_key),
        }));
        await sm.start();
        Object firstEvent;
        final nextProcessedMessage =
            StreamQueue(sm.processedMessages).next.then((pm) => firstEvent ??= pm);
        final nextTransition = StreamQueue(sm.transitions).next.then((t) => firstEvent ??= t);

        await sm.currentState.sendMessage(Object());
        await Future.any([nextProcessedMessage, nextTransition]);

        expect(firstEvent, isA<MessageProcessed>());
      });

      test('should emit processedMessage', () async {
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
    });
  });
}
