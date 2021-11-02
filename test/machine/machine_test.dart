// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'fixture/fixture_util.dart';
import 'fixture/flat_tree.dart' as flat_tree;
import 'fixture/data_tree.dart' as data_tree;
import 'fixture/state_data.dart';
import 'fixture/tree.dart';

void main() {
  group('Machine', () {
    group('processMessage', () {
      test('should return unhandled if current state is final', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_key: (msgCtx) {
            // Root state (or any states) should not have it's handler invoked
            expect(false, isTrue);
            return msgCtx.unhandled();
          }
        });
        final machine = createMachine(buildTree);

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
        final machine = createMachine(buildTree);
        final msg = Object();

        final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

        expect(msgProcessed, isA<HandledMessage>());
        final handled = msgProcessed as HandledMessage;
        expect(handled.message, same(msg));
        expect(handled.receivingState, equals(r_a_a_1_key));
        expect(handled.handlingState, equals(r_a_a_1_key));
        expect(handled.transition, isNotNull);
        expect(handled.transition!.exitPath, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
        expect(handled.transition!.entryPath, orderedEquals([r_b_key, r_b_1_key]));
      });

      group('GoToResult', () {
        test('should handle message with current state', () async {
          final buildTree = flat_tree.treeBuilder(state1Handler: (msgCtx) {
            return msgCtx.goTo(flat_tree.r_2_key);
          });
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), flat_tree.r_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(flat_tree.r_1_key));
          expect(handled.handlingState, equals(flat_tree.r_1_key));
          expect(handled.transition, isNotNull);
          expect(handled.transition!.exitPath, orderedEquals([flat_tree.r_1_key]));
          expect(handled.transition!.entryPath, orderedEquals([flat_tree.r_2_key]));
        });

        test('should handle message with ancestor states if unhandled by current state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) => msgCtx.goTo(r_b_1_key),
          });
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.transition, isNotNull);
          expect(handled.transition!.exitPath, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.transition!.entryPath, orderedEquals([r_b_key, r_b_1_key]));
        });

        test('should follow initial children at destination state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
          });
          final machine = createMachine(buildTree);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.message, same(msg));
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.transition, isNotNull);
          expect(handled.transition!.exitPath, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.transition!.entryPath, orderedEquals([r_b_key, r_b_1_key]));
        });

        test('should include transition in result', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
          });
          final machine = createMachine(buildTree);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.transition, isNotNull);
          expect(handled.transition!.lca, equals(r_key));

          expectPath(handled.transition!, [r_a_a_1_key, r_a_a_key, r_a_key], [r_b_key, r_b_1_key]);
        });

        test('should call initial child after state is entered', () async {
          var counter = 1;
          final entryCounters = <StateKey, int>{};
          final initChildCounters = <StateKey, int>{};
          final buildTree = treeBuilder(
            createInitialChildCallback: (key) {
              return (ctx) {
                initChildCounters[key] = counter++;
              };
            },
            createEntryHandler: (key) {
              return (ctx) {
                entryCounters[key] = counter++;
              };
            },
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
            },
          );
          final machine = createMachine(buildTree);

          await machine.enterInitialState();
          for (var parent in [r_key, r_a_key, r_a_a_key]) {
            expect(entryCounters[parent]! < initChildCounters[parent]!, isTrue);
          }
        });

        test('should call transition handlers in order', () async {
          var order = 1;
          var entryOrder = <StateKey, int>{};
          var exitOrder = <StateKey, int>{};
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
          final machine = createMachine(buildTree);

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
                  // transition action is called after all states are exited, but befire any are
                  // entered
                  expect(ctx.exited, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
                  expect(ctx.entered, orderedEquals([]));
                },
              );
            }
          });
          final machine = createMachine(buildTree);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.message, same(msg));
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.transition, isNotNull);
          expect(handled.transition!.exitPath, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.transition!.entryPath, orderedEquals([r_b_key, r_b_1_key]));
          expect(actionCalled, isTrue);
        });

        test('should go to final state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_X_key),
          });
          final machine = createMachine(buildTree);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.message, same(msg));
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.transition!.exitPath, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.transition!.entryPath, orderedEquals([r_X_key]));
        });

        test('should pass payload to transition context', () async {
          final payload = Object();
          final payloadMap = <StateKey, Object?>{};
          final buildTree = treeBuilder(
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_1_key, payload: payload),
            },
            createExitHandler: (key) => (ctx) => payloadMap[key] = ctx.payload,
            createEntryHandler: (key) => (ctx) => payloadMap[key] = ctx.payload,
          );
          final machine = createMachine(buildTree);
          final msg = Object();

          await machine.processMessage(msg, r_a_a_1_key);

          final exited = [r_a_a_1_key, r_a_a_key, r_a_key];
          final entered = [r_b_key, r_b_1_key];
          for (var key in exited.followedBy(entered)) {
            expect(payloadMap[key], same(payload));
          }
        });

        test('should re-enter intial children if going to ancestor state', () async {
          var counter = 1;
          var entryCounters = <StateKey, int>{};
          var buildTree = treeBuilder(
            createEntryHandler: (key) => (ctx) {
              entryCounters[key] = counter++;
            },
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_a_key),
            },
          );
          final machine = createMachine(buildTree);
          await machine.enterInitialState(r_a_a_1_key);

          counter = 1;
          entryCounters = <StateKey, int>{};
          await machine.processMessage(Object());

          expect(entryCounters[r_a_a_key], equals(1));
          expect(entryCounters[r_a_a_2_key], equals(2));
        });

        test('should re-enter target leaf state if re-entering', () async {
          var counter = 1;
          var entryCounters = <StateKey, int>{};
          var exitCounters = <StateKey, int>{};
          var buildTree = treeBuilder(
            createEntryHandler: (key) => (ctx) {
              entryCounters[key] = counter++;
            },
            createExitHandler: (key) => (ctx) {
              exitCounters[key] = counter++;
            },
            messageHandlers: {
              r_b_key: (msgCtx) => msgCtx.goTo(r_b_2_key, reenterTarget: true),
            },
          );
          final machine = createMachine(buildTree);
          await machine.enterInitialState(r_b_2_key);

          counter = 1;
          entryCounters = <StateKey, int>{};
          await machine.processMessage(Object());

          expect(exitCounters[r_b_2_key], equals(1));
          expect(entryCounters[r_b_2_key], equals(2));
        });

        test('should throw if re-entering root node', () async {
          var buildTree = treeBuilder(
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_key, reenterTarget: true),
            },
          );
          final machine = createMachine(buildTree);
          await machine.enterInitialState(r_a_a_1_key);

          expect(() => machine.processMessage(Object()), throwsStateError);
        });

        test('should clear state data when exiting state', () async {
          var buildTree = data_tree.treeBuilder(
            messageHandlers: {
              data_tree.r_a_a_1_key: (msgCtx) {
                msgCtx.updateOrThrow<LeafData1>((d) => d..counter = 10);
                msgCtx.updateOrThrow<ImmutableData>(
                  (d) => ImmutableData((b) => b
                    ..name = 'bob'
                    ..price = d.price),
                  key: data_tree.r_a_key,
                );
                return msgCtx.goTo(data_tree.r_b_1_key, reenterTarget: true);
              },
            },
          );
          final machine = createMachine(buildTree);
          await machine.enterInitialState(r_a_a_1_key);

          await machine.processMessage(Object());

          expect(machine.nodes[r_a_a_1_key]!.treeNode.data, isNull);
          expect(machine.nodes[r_a_key]!.treeNode.data, isNull);
        });
      });

      group('UnhandledResult', () {
        test('should try to handle message with all ancestor states', () async {
          final buildTree = treeBuilder();
          final machine = createMachine(buildTree);
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
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.transition, isNull);
        });

        test('should stay in current state when ancestor state is handling state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) => msgCtx.stay(),
          });
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.transition, isNull);
        });
      });
      group('SelfTransitionResult', () {
        test('should re-enter leaf state when current state is handling state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goToSelf(),
          });
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_a_1_key));
          expect(handled.transition, isNotNull);
          expect(handled.transition!.exitPath, [r_a_a_1_key]);
          expect(handled.transition!.entryPath, [r_a_a_1_key]);
        });

        test('should re-enter leaf and interior states when interior state is handling state',
            () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) => msgCtx.goToSelf(),
          });
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.transition!.exitPath, [r_a_a_1_key, r_a_a_key, r_a_key]);
          expect(handled.transition!.entryPath, [r_a_key, r_a_a_key, r_a_a_1_key]);
        });

        test('should call transition action if provided', () async {
          var actionCalled = false;
          final buildTree = treeBuilder(messageHandlers: {
            r_a_key: (msgCtx) {
              return msgCtx.goToSelf(
                transitionAction: (ctx) {
                  actionCalled = true;
                  expect(ctx.requestedTransition.from, equals(r_a_a_1_key));
                  expect(ctx.requestedTransition.to, equals(r_a_a_1_key));
                  expect(
                      ctx.requestedTransition.path,
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
          final machine = createMachine(buildTree);

          final msgProcessed = await machine.processMessage(Object(), r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.receivingState, equals(r_a_a_1_key));
          expect(handled.handlingState, equals(r_a_key));
          expect(handled.transition!.exitPath, [r_a_a_1_key, r_a_a_key, r_a_key]);
          expect(handled.transition!.entryPath, [r_a_key, r_a_a_key, r_a_a_1_key]);
          expect(actionCalled, isTrue);
        });
      });
    });
  });
}

void expectPath(
  Transition transition,
  Iterable<StateKey> exited,
  Iterable<StateKey> entered, {
  StateKey? to,
}) {
  expect(transition.from, equals(exited.isNotEmpty ? exited.first : entered.first));
  expect(transition.to, equals(entered.last));
  expect(transition.exitPath, orderedEquals(exited));
  expect(transition.entryPath, orderedEquals(entered));
  expect(
    transition.path,
    orderedEquals(exited.followedBy(entered)),
  );
}
