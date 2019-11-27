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

        expectPath(transCtx, [], [r_key, r_a_key, r_a_a_key, r_a_a_2_key]);
      });

      test('should descend to initial state when initial state is a leaf', () async {
        final MachineTransitionContext transCtx = await machine.enterInitialState(r_b_1_key);

        expectPath(transCtx, [], [r_key, r_b_key, r_b_1_key], to: r_b_1_key);
      });

      test('should descend to initial state, then follow initial children', () async {
        final MachineTransitionContext transCtx = await machine.enterInitialState(r_a_a_key);

        expectPath(transCtx, [], [r_key, r_a_key, r_a_a_key, r_a_a_2_key], to: r_a_a_key);
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

      test('should return unhandled if current state is terminal', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_key: (msgCtx) {
            // Root state (or any states) should not have it's handler invoked
            expect(false, isTrue);
            return msgCtx.unhandled();
          }
        });
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        final msg = Object();
        final msgProcessed = await machine.processMessage(msg, r_X_key);

        expect(msgProcessed, isA<UnhandledMessage>());
        final handled = msgProcessed as UnhandledMessage;
        expect(handled.message, same(msg));
        expect(handled.receivingState, equals(r_X_key));
        expect(handled.notifiedStates, isEmpty);
      });

      test('should process with async handlers', () async {
        final delayInMillis = 50;
        final buildTree = treeBuilder(
          createEntryHandler: (key) => (ctx) =>
              Future.delayed(Duration(milliseconds: delayInMillis), () => emptyTransitionHandler),
          createExitHandler: (key) => (ctx) =>
              Future.delayed(Duration(milliseconds: delayInMillis), () => emptyTransitionHandler),
          createMessageHandler: (key) =>
              (ctx) => Future.delayed(Duration(milliseconds: delayInMillis), () => ctx.unhandled()),
          messageHandlers: {
            r_a_a_1_key: (msgCtx) =>
                Future.delayed(Duration(milliseconds: delayInMillis), () => msgCtx.goTo(r_b_1_key)),
          },
        );
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) => msgCtx.goTo(r_b_1_key),
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
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

        test('should call transition handlers in order', () async {
          var order = 1;
          final entryOrder = Map<StateKey, int>();
          final exitOrder = Map<StateKey, int>();
          TransitionHandler createEntryHandler(StateKey key) => (_) {
                entryOrder[key] = order++;
              };
          TransitionHandler createExitHandler(StateKey key) => (_) {
                exitOrder[key] = order++;
              };

          final buildTree = treeBuilder(
            createEntryHandler: createEntryHandler,
            createExitHandler: createExitHandler,
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
            },
          );
          final buildCtx = BuildContext();
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          await machine.enterInitialState(r_a_a_1_key);

          // Reset order so we ignore the transitions from entering intial state
          order = 1;
          await machine.processMessage(Object());

          var expectedOrder = 1;
          for (final key in [r_a_a_1_key, r_a_a_key, r_a_key]) {
            expect(exitOrder[key], equals(expectedOrder++));
          }
          for (final key in [r_b_key, r_b_1_key]) {
            expect(entryOrder[key], equals(expectedOrder++));
          }
        });

        test('should call transition action if provided', () async {
          var actionCalled = false;
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) {
              return msgCtx.goTo(
                r_b_key,
                transitionAction: (ctx) {
                  actionCalled = true;
                  expect(ctx.from, equals(r_a_a_1_key));
                  // Initial children have not been calculated yet, since r_b has not yet been
                  // entered, so toNode is still r_b_key
                  expect(ctx.to, equals(r_b_key));
                  expect(ctx.traversed(), orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
                },
              );
            }
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

        test('should go to terminal state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_X_key),
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
          expect(handled.enteredStates, orderedEquals([r_X_key]));
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.stay(),
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) => msgCtx.stay(),
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goToSelf(),
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) => msgCtx.goToSelf(),
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
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) {
              return msgCtx.goToSelf(
                transitionAction: (ctx) {
                  actionCalled = true;
                  expect(ctx.from, equals(r_a_a_1_key));
                  expect(ctx.to, equals(r_a_a_1_key));
                  expect(
                      ctx.path,
                      equals([
                        r_a_a_1_key,
                        r_a_a_key,
                        r_a_key,
                        r_a_key,
                        r_a_a_key,
                        r_a_a_1_key,
                      ]));
                },
              );
            }
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

void expectPath(
  TransitionContext transCtx,
  Iterable<StateKey> exited,
  Iterable<StateKey> entered, {
  StateKey to,
}) {
  expect(transCtx.from, equals(exited.isNotEmpty ? exited.first : entered.first));
  expect(transCtx.end, equals(entered.last));
  if (to != null) {
    expect(transCtx.to, equals(to));
    expect(
      transCtx.path,
      orderedEquals(exited.followedBy(entered.takeWhile((e) => e != to).followedBy([to]))),
    );
  }
  expect(transCtx.exited, orderedEquals(exited));
  expect(transCtx.entered, orderedEquals(entered));
  expect(
    transCtx.traversed(),
    orderedEquals(exited.followedBy(entered)),
  );
}
