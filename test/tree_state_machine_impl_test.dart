import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/src/data_provider.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

import 'fixture/data_tree.dart' as data_tree;
import 'fixture/flat_tree_1.dart' as flat_tree;
import 'fixture/tree_1.dart';
import 'fixture/tree_data.dart';

final _getCurrentLeafData = DelegateObservableData();

void main() {
  group('Machine', () {
    group('enterInitialState', () {
      final buildCtx = TreeBuildContext(_getCurrentLeafData);
      var buildTree = treeBuilder();
      final rootNode = buildTree(buildCtx);
      final machine = Machine(rootNode, buildCtx.nodes);

      test('should follow initial children when starting at root', () async {
        final transition = await machine.enterInitialState(rootNode.key);

        expectPath(transition, [], [r_key, r_a_key, r_a_a_key, r_a_a_2_key]);
      });

      test('should descend to initial state when initial state is a leaf', () async {
        final transition = await machine.enterInitialState(r_b_1_key);

        expectPath(transition, [], [r_key, r_b_key, r_b_1_key], to: r_b_1_key);
      });

      test('should descend to initial state, then follow initial children', () async {
        final transition = await machine.enterInitialState(r_a_a_key);

        expectPath(transition, [], [r_key, r_a_key, r_a_a_key, r_a_a_2_key], to: r_a_a_key);
      });

      test('should throw if initialChild returns null', () {
        final buildTree = rootBuilder(
          key: r_key,
          createState: (key) => DelegateState(),
          initialChild: (_) => null,
          children: [
            leafBuilder(key: r_a_1_key, createState: (key) => DelegateState()),
          ],
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });

      test('should throw if initialChild references a state that is not a child', () {
        final buildTree = rootBuilder(
            key: r_key,
            createState: (key) => DelegateState(),
            initialChild: (_) => r_a_a_1_key,
            children: [
              leafBuilder(key: r_a_1_key, createState: (key) => DelegateState()),
            ]);
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });
    });

    group('processMessage', () {
      test('should throw if handling state returns null from onMessage', () {
        final buildTree = flat_tree.treeBuilder(state1Handler: (msgCtx) => null);
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(
          () async => await machine.processMessage(Object(), flat_tree.r_1_key),
          throwsStateError,
        );
      });

      test('should return unhandled if current state is final', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_key: (msgCtx) {
            // Root state (or any states) should not have it's handler invoked
            expect(false, isTrue);
            return msgCtx.unhandled();
          }
        });
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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

        test('should follow initial children at destination state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
          });
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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

        test('should include transition in result', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
          });
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);
          final msg = Object();

          final msgProcessed = await machine.processMessage(msg, r_a_a_1_key);

          expect(msgProcessed, isA<HandledMessage>());
          final handled = msgProcessed as HandledMessage;
          expect(handled.transition, isNotNull);

          expectPath(handled.transition, [r_a_a_1_key, r_a_a_key, r_a_key], [r_b_key, r_b_1_key]);
          expect(handled.transition.active, [r_b_1_key, r_b_key, r_key]);
        });

        test('should call initial child after state is entered', () async {
          var counter = 1;
          final entryCounters = <StateKey, int>{};
          final initChildCounters = <StateKey, int>{};
          final buildTree = treeBuilder(
            createInitialChildCallback: (key) => (ctx) {
              initChildCounters[key] = counter++;
            },
            createEntryHandler: (key) => (ctx) {
              entryCounters[key] = counter++;
            },
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_key),
            },
          );
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);

          await machine.enterInitialState();
          for (var parent in [r_key, r_a_key, r_a_a_key]) {
            expect(entryCounters[parent] < initChildCounters[parent], isTrue);
          }
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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

        test('should go to final state', () async {
          final buildTree = treeBuilder(messageHandlers: {
            r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_X_key),
          });
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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

        test('should pass payload to transition context', () async {
          final payload = Object();
          final payloadMap = <StateKey, Object>{};
          final buildTree = treeBuilder(
            messageHandlers: {
              r_a_a_1_key: (msgCtx) => msgCtx.goTo(r_b_1_key, payload: payload),
            },
            createExitHandler: (key) => (ctx) => payloadMap[key] = ctx.payload,
            createEntryHandler: (key) => (ctx) => payloadMap[key] = ctx.payload,
          );
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
          final rootNode = buildTree(buildCtx);
          final machine = Machine(rootNode, buildCtx.nodes);
          final msg = Object();

          await machine.processMessage(msg, r_a_a_1_key);

          final exited = [r_a_a_1_key, r_a_a_key, r_a_key];
          final entered = [r_b_key, r_b_1_key];
          for (var key in exited.followedBy(entered)) {
            expect(payloadMap[key], same(payload));
          }
        });
      });

      group('UnhandledResult', () {
        test('should try to handle message with all ancestor states', () async {
          final buildTree = treeBuilder();
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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
          final buildCtx = TreeBuildContext(_getCurrentLeafData);
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

  group('MachineMessageContext', () {
    group('data', () {
      test('should return data for handling state', () async {
        final dataByKey = <StateKey, Object>{};
        final buildTree = data_tree.treeBuilder(
          createMessageHandler: (key) => (ctx) {
            dataByKey[key] = ctx.data();
            return ctx.unhandled();
          },
        );

        Machine machine;
        final buildCtx = TreeBuildContext(
          DelegateObservableData(getData: () => machine.currentNode.data()),
        );
        final rootNode = buildTree(buildCtx);
        machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_2_key], isA<LeafData2>());
        expect(dataByKey[r_a_a_key], isA<LeafDataBase>());
        expect(dataByKey[r_a_key], isA<ImmutableData>());
        expect(dataByKey[r_key], isA<SpecialDataD>());
      });

      test('should return null if handling state has no data', () async {
        final dataByKey = <StateKey, Object>{};
        final buildTree = treeBuilder(
          createMessageHandler: (key) => (ctx) {
            dataByKey[key] = ctx.data<Object>();
            return ctx.unhandled();
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_2_key], isNull);
        expect(dataByKey[r_a_a_key], isNull);
        expect(dataByKey[r_a_key], isNull);
        expect(dataByKey[r_key], isNull);
      });
    });

    group('schedule', () {
      test('should post message immediately when duration is 0', () async {
        final completer = Completer();
        var receivedMessage = false;
        final scheduleMsg = Object();
        final scheduledMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) => ctx.post(scheduleMsg),
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, scheduleMsg)) {
                ctx.schedule(() => scheduledMsg);
              } else if (identical(ctx.message, scheduledMsg)) {
                receivedMessage = true;
                completer.complete();
              }
              return ctx.stay();
            }
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await completer.future;

        expect(receivedMessage, isTrue);
      });

      test('should post messages when periodic is true', () async {
        final completer = Completer();
        var receiveCount = 0;
        Dispose dispose = null;
        final scheduleMsg = Object();
        final scheduledMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) => ctx.post(scheduleMsg),
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, scheduleMsg)) {
                dispose = ctx.schedule(
                  () => scheduledMsg,
                  periodic: true,
                  duration: Duration(milliseconds: 10),
                );
              } else if (identical(ctx.message, scheduledMsg)) {
                receiveCount++;
                if (receiveCount == 3) {
                  dispose();
                  completer.complete();
                }
              }
              return ctx.stay();
            }
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
      });

      test('should be canceled when dispose function is called', () async {
        final completer = Completer();
        var receiveCount = 0;
        Dispose dispose = null;
        final scheduleMsg = Object();
        final scheduledMsg = Object();
        final completionMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) => ctx.post(scheduleMsg),
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, scheduleMsg)) {
                dispose = ctx.schedule(
                  () => scheduledMsg,
                  periodic: true,
                  duration: Duration(milliseconds: 10),
                );
              } else if (identical(ctx.message, scheduledMsg)) {
                receiveCount++;
                if (receiveCount == 3) {
                  dispose();
                  ctx.schedule(() => completionMsg, duration: Duration(milliseconds: 30));
                }
              } else if (identical(ctx.message, completionMsg)) {
                completer.complete();
              }

              return ctx.stay();
            }
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
      });

      test('should be canceled when scheduling state is exited', () async {
        final completer = Completer();
        var receiveCount = 0;
        final scheduleMsg = Object();
        final scheduledMsg = Object();
        final completionMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) => ctx.post(scheduleMsg),
            r_b_1_key: (ctx) => ctx.post(scheduleMsg),
          },
          messageHandlers: {
            r_a_a_key: (ctx) {
              if (identical(ctx.message, scheduleMsg)) {
                ctx.schedule(
                  () => scheduledMsg,
                  periodic: true,
                  duration: Duration(milliseconds: 10),
                );
              } else if (identical(ctx.message, scheduledMsg)) {
                receiveCount++;
                if (receiveCount == 3) {
                  return ctx.goTo(r_b_1_key);
                }
              }
              return ctx.unhandled();
            },
            r_b_1_key: (ctx) {
              if (identical(ctx.message, scheduledMsg)) {
                // We should not get here, timer should have been canceled.
                receiveCount++;
              } else if (identical(ctx.message, scheduleMsg)) {
                // Schedule message that will finish the test in 50 milliseconds. That will give
                // enough time for the periodic messages scheduled in r_a_a state to arrive
                // (but they won't because timer should be canceled when exiting r_a_a)
                ctx.schedule(
                  () => completionMsg,
                  duration: Duration(milliseconds: 50),
                );
              } else if (identical(ctx.message, completionMsg)) {
                completer.complete();
              }
              return ctx.unhandled();
            }
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
        expect(machine.currentNode.key, equals(r_b_1_key));
      });
    });
  });

  group('MachineTransitionContext', () {
    group('post', () {
      test('Should send message to end state when transition completes', () async {
        final completer = Completer();
        var receivedMessage = false;
        final msg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) => ctx.post(msg),
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, msg)) {
                receivedMessage = true;
                completer.complete();
              }
              return ctx.stay();
            }
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);
        await machine.enterInitialState();
        await completer.future;

        expect(receivedMessage, isTrue);
      });

      test('Should send messages to end state if called more than once', () async {
        final completer = Completer();
        var receivedMessage1 = false;
        var receivedMessage2 = false;
        final msg1 = Object();
        final msg2 = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) {
              // This will be handled by r_a_a_2 after initial state is entered, and trigger a
              // transition to r_b_1
              ctx.post(msg1);
              // This will be handled by r_b_1
              ctx.post(msg2);
            }
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, msg1)) {
                receivedMessage1 = true;
              }
              return ctx.goTo(r_b_1_key);
            },
            r_b_1_key: (ctx) {
              if (identical(ctx.message, msg2)) {
                if (!receivedMessage1) {
                  // messages should be received in order posted
                  expect(false, isTrue);
                }
                receivedMessage2 = true;
              }
              if (receivedMessage1 && receivedMessage2) {
                completer.complete();
              }
              return ctx.stay();
            }
          },
        );
        final buildCtx = TreeBuildContext(_getCurrentLeafData);
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        await machine.enterInitialState();
        await completer.future;

        expect(receivedMessage1, isTrue);
        expect(receivedMessage2, isTrue);
        expect(machine.currentNode.key, equals(r_b_1_key));
      });
    });
  });
}

void expectPath(
  Transition transition,
  Iterable<StateKey> exited,
  Iterable<StateKey> entered, {
  StateKey to,
}) {
  expect(transition.from, equals(exited.isNotEmpty ? exited.first : entered.first));
  expect(transition.to, equals(entered.last));
  expect(transition.exited, orderedEquals(exited));
  expect(transition.entered, orderedEquals(entered));
  expect(
    transition.traversed,
    orderedEquals(exited.followedBy(entered)),
  );
}
