import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

import 'tree_1.dart';
import 'flat_tree_1.dart' as flat_tree;

void main() {
  group('Machine', () {
    group('enterInitialState', () {
      final buildCtx = BuildContext();
      var buildTree = treeBuilder();
      final rootNode = buildTree(buildCtx);
      final machine = Machine(rootNode, buildCtx.nodes);

      test('should follow initial children when starting at root', () async {
        final MachineTransitionContext transCtx = await machine.enterInitialState(rootNode.key);

        expect(transCtx.from, equals(r_key));

        expect(transCtx.to, equals(r_a_a_2_key));
        expect(
          transCtx.path(),
          orderedEquals([r_key, r_a_key, r_a_a_key, r_a_a_2_key]),
        );
      });

      test('should descend to initial state when initial state is a leaf', () async {
        final leafNode = buildCtx.nodes[r_b_1_key];

        final MachineTransitionContext transCtx = await machine.enterInitialState(leafNode.key);

        expect(transCtx.from, equals(r_key));
        expect(transCtx.to, equals(leafNode.key));
        expect(
          transCtx.path().map((ref) => ref),
          orderedEquals([r_key, r_b_key, r_b_1_key]),
        );
      });

      test(
          'should descend to initial state, then follow initial children, when initial state an interior',
          () async {
        final interiorNode = buildCtx.nodes[r_a_a_key];

        final MachineTransitionContext transCtx = await machine.enterInitialState(interiorNode.key);

        expect(transCtx.from, equals(r_key));
        expect(transCtx.to, equals(r_a_a_2_key));
        expect(
          transCtx.path(),
          orderedEquals([r_key, r_a_key, r_a_a_key, r_a_a_2_key]),
        );
      });

      test('should throw if initialChild returns null', () {
        final buildTree = BuildRoot.keyed(
          key: r_key,
          state: (key) => DelegateState(),
          initialChild: (_) => null,
          children: [
            BuildLeaf.keyed(r_a_1_key, (key) => DelegateState()),
          ],
        );
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });

      test('should throw if initialChild references a state that is not a child', () {
        final buildTree = BuildRoot.keyed(
            key: r_key,
            state: (key) => DelegateState(),
            initialChild: (_) => r_a_a_1_key,
            children: [
              BuildLeaf.keyed(r_a_1_key, (key) => DelegateState()),
            ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });
    });

    group('processMessage', () {
      test('should throw if handling state returns null from onMessage', () {
        final buildTree = flat_tree.treeBuilder(state1Handler: (msgCtx) => null);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(
          () async => await machine.processMessage(Object(), flat_tree.r_1_key),
          throwsStateError,
        );
      });

      group('GoToResult', () {
        test('should handle message with current state', () async {
          final buildTree = flat_tree.treeBuilder(state1Handler: (msgCtx) {
            return msgCtx.goTo(flat_tree.r_2_key);
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), flat_tree.r_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(flat_tree.r_1_key));
          expect(handled.handlingState, equals(flat_tree.r_1_key));
          expect(handled.exitedStates, orderedEquals([flat_tree.r_1_key]));
          expect(handled.enteredStates, orderedEquals([flat_tree.r_2_key]));
        });

        test('should handle message with ancestor states if unhandled by current state', () async {
          final buildTree = treeBuilder(r_a_handler: (msgCtx) {
            return msgCtx.goTo(r_b_1_key);
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
        });

        test('should follow initial children at to state', () async {
          final buildTree = treeBuilder(r_a_a_1_handler: (msgCtx) {
            return msgCtx.goTo(r_b_key);
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.message, same(msg));
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
        });

        test('should call transition action if provided', () async {
          var actionCalled = false;

          final buildTree = treeBuilder(r_a_a_1_handler: (msgCtx) {
            return msgCtx.goTo(
              r_b_key,
              transitionAction: (ctx) {
                actionCalled = true;
                expect(ctx.from, equals(r_a_a_1_key));
                expect(ctx.to, equals(r_b_1_key));
              },
            );
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.message, same(msg));
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
          expect(actionCalled, isTrue);
        });
      });

      group('UnhandledResult', () {
        test('should try to handle message with all ancestor states', () async {
          final buildTree = treeBuilder();
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<UnhandledMessage>());
          final handled = msgProcessed as UnhandledMessage;
          expect(handled.message, same(msg));
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.notifiedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key, r_key]));
        });
      });

      group('InternalTransitionResult', () {
        test('should stay in current state when current state is handling state', () async {
          final buildTree = treeBuilder(r_a_a_1_handler: (msgCtx) {
            return msgCtx.stay();
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.exitedStates, isEmpty);
          expect(handled.enteredStates, isEmpty);
        });

        test('should stay in current state when ancestor state is handling state', () async {
          final buildTree = treeBuilder(r_a_handler: (msgCtx) {
            return msgCtx.stay();
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.exitedStates, isEmpty);
          expect(handled.enteredStates, isEmpty);
        });
      });

      group('SelfTransitionResult', () {
        test('should re-enter leaf state when current state is handling state', () async {
          final buildTree = treeBuilder(r_a_a_1_handler: (msgCtx) {
            return msgCtx.goToSelf();
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.exitedStates, [r_a_a_1_key]);
          expect(handled.enteredStates, [r_a_a_1_key]);
        });

        test('should re-enter leaf and interior states when interior state is handling state',
            () async {
          final buildTree = treeBuilder(r_a_handler: (msgCtx) {
            return msgCtx.goToSelf();
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.exitedStates, [r_a_a_1_key, r_a_a_key, r_a_key]);
          expect(handled.enteredStates, [r_a_key, r_a_a_key, r_a_a_1_key]);
        });

        test('should call transition action if provided', () async {
          var actionCalled = false;

          final buildTree = treeBuilder(r_a_handler: (msgCtx) {
            return msgCtx.goToSelf(transitionAction: (ctx) {
              actionCalled = true;
              expect(ctx.from, equals(r_a_a_1_key));
              expect(ctx.to, equals(r_a_a_1_key));
            });
          });
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.exitedStates, [r_a_a_1_key, r_a_a_key, r_a_key]);
          expect(handled.enteredStates, [r_a_key, r_a_a_key, r_a_a_1_key]);
          expect(actionCalled, isTrue);
        });
      });
    });
  });
}
