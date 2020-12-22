import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/src/data_provider.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_helpers.dart';

import 'fixture/data_tree.dart' as data_tree;
import 'fixture/flat_tree_1.dart' as flat_tree;
import 'fixture/tree_1.dart';
import 'fixture/tree_data.dart';

void main() {
  Machine createMachine(NodeBuilder<RootNode> buildTree) {
    Machine machine;
    final buildCtx = TreeBuildContext(
      DelegateObservableData(getData: () => machine.currentNode.data()),
    );
    final rootNode = buildTree.build(buildCtx);
    machine = Machine(
      rootNode,
      buildCtx.nodes,
      (message) => Timer.run(() => machine.processMessage(message)),
    );
    return machine;
  }

  group('Machine', () {
    group('enterInitialState', () {
      final machine = createMachine(data_tree.treeBuilder());

      test('should follow initial children when starting at root', () async {
        final transition = await machine.enterInitialState(r_key);

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
        final buildTree = Root(
          key: r_key,
          createState: (key) => DelegateState(),
          initialChild: (_) => null,
          children: [
            Leaf(key: r_a_1_key, createState: (key) => DelegateState()),
          ],
        );
        final machine = createMachine(buildTree);

        expect(() => machine.enterInitialState(r_key), throwsStateError);
      });

      test('should throw if initialChild references a state that is not a child', () {
        final buildTree = Root(
            key: r_key,
            createState: (key) => DelegateState(),
            initialChild: (_) => r_a_a_1_key,
            children: [
              Leaf(key: r_a_1_key, createState: (key) => DelegateState()),
            ]);
        final machine = createMachine(buildTree);

        expect(() => machine.enterInitialState(r_key), throwsStateError);
      });
    });

    group('processMessage', () {
      test('should throw if handling state returns null from onMessage', () {
        final buildTree = flat_tree.treeBuilder(state1Handler: (msgCtx) => null);
        final machine = createMachine(buildTree);

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
        expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
        expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
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
          expect(handled.exitedStates, orderedEquals([flat_tree.r_1_key]));
          expect(handled.enteredStates, orderedEquals([flat_tree.r_2_key]));
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
          expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
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
          expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
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
          final machine = createMachine(buildTree);

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
                  expect(ctx.from, equals(r_a_a_1_key));
                  // Initial children have not been calculated yet, since r_b has not yet been
                  // entered, so toNode is still r_b_key
                  expect(ctx.to, equals(r_b_key));
                  expect(ctx.traversed(), orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
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
          expect(handled.exitedStates, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key]));
          expect(handled.enteredStates, orderedEquals([r_b_key, r_b_1_key]));
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

        test('should re-enter ancestor state and intial children if re-entering ancestor state',
            () async {
          var counter = 1;
          var entryCounters = <StateKey, int>{};
          var buildTree = treeBuilder(
            createEntryHandler: (key) => (ctx) {
              entryCounters[key] = counter++;
            },
            messageHandlers: {
              r_b_2_key: (msgCtx) => msgCtx.goTo(r_b_key, reenterTarget: true),
            },
          );
          final machine = createMachine(buildTree);
          await machine.enterInitialState(r_b_2_key);

          counter = 1;
          entryCounters = <StateKey, int>{};
          await machine.processMessage(Object());

          expect(entryCounters[r_b_key], equals(1));
          expect(entryCounters[r_b_1_key], equals(2));
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

        test('should reset provider when exiting state', () async {
          var buildTree = data_tree.treeBuilder(
            messageHandlers: {
              data_tree.r_a_a_1_key: (msgCtx) {
                msgCtx.replaceData<LeafData1>((d) => d..counter = 10);
                msgCtx.replaceData<ImmutableData>((d) => d.rebuild((b) => b.name = 'Bob'),
                    key: data_tree.r_a_key);
                return msgCtx.goTo(data_tree.r_b_1_key, reenterTarget: true);
              },
            },
          );
          final machine = createMachine(buildTree);
          await machine.enterInitialState(r_a_a_1_key);

          await machine.processMessage(Object());

          expect(machine.nodes[data_tree.r_a_a_1_key].node.data<LeafData1>().counter == 10, false);
          expect(machine.nodes[data_tree.r_a_key].node.data<ImmutableData>().name == 'Bob', false);
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
          expect(handled.exitedStates, isEmpty);
          expect(handled.enteredStates, isEmpty);
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
          expect(handled.exitedStates, isEmpty);
          expect(handled.enteredStates, isEmpty);
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
          expect(handled.exitedStates, [r_a_a_1_key]);
          expect(handled.enteredStates, [r_a_a_1_key]);
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
          final machine = createMachine(buildTree);

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
        final machine = createMachine(buildTree);
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
        final machine = createMachine(buildTree);
        await machine.enterInitialState();

        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_2_key], isNull);
        expect(dataByKey[r_a_a_key], isNull);
        expect(dataByKey[r_a_key], isNull);
        expect(dataByKey[r_key], isNull);
      });

      test('should return null if descendant data is requested', () async {
        final dataByKey = <StateKey, Object>{};
        final buildTree = data_tree.treeBuilder(messageHandlers: {
          r_a_a_key: (ctx) {
            dataByKey[r_a_a_key] = ctx.data<LeafData2>(r_a_a_2_key);
            return ctx.unhandled();
          },
          r_a_key: (ctx) {
            dataByKey[r_a_key] = ctx.data<LeafData2>(r_a_a_key);
            return ctx.unhandled();
          }
        });

        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_key], isNull);
        expect(dataByKey[r_a_key], isNull);
      });
    });

    group('replaceData', () {
      test('should replace data in ancestor state', () async {
        final buildTree = data_tree.treeBuilder(messageHandlers: {
          data_tree.r_a_a_1_key: (ctx) {
            ctx.replaceData<ImmutableData>((current) => current.rebuild((b) => b
              ..name = 'Jim'
              ..price = 2));
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(data_tree.r_a_a_1_key);

        await machine.processMessage(Object());

        DataProvider<ImmutableData> ancestorProvider =
            machine.nodes[data_tree.r_a_key].node.dataProvider();
        expect(ancestorProvider.data.name, equals('Jim'));
        expect(ancestorProvider.data.price, equals(2));
      });

      test('should replace data in closest state', () async {
        final r_a_data = ImmutableData((b) => b
          ..name = 'John'
          ..price = 10);
        final r_a_1_data = ImmutableData((b) => b
          ..name = 'Pete'
          ..price = 5);

        final buildTree = data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_key: r_a_data,
            data_tree.r_a_1_key: r_a_1_data,
          },
          messageHandlers: {
            data_tree.r_a_1_key: (ctx) {
              ctx.replaceData<ImmutableData>((current) => current.rebuild((b) => b
                ..name = 'Jim'
                ..price = 2));
              return ctx.stay();
            }
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState(data_tree.r_a_1_key);

        await machine.processMessage(Object());

        DataProvider<ImmutableData> provider =
            machine.nodes[data_tree.r_a_1_key].node.dataProvider();
        expect(provider.data.name, equals('Jim'));
        expect(provider.data.price, equals(2));

        DataProvider<ImmutableData> ancestorProvider =
            machine.nodes[data_tree.r_a_key].node.dataProvider();
        expect(ancestorProvider.data, same(r_a_data));
      });

      test('should replace data in ancestor state by key', () async {
        final buildTree = data_tree.treeBuilder(messageHandlers: {
          data_tree.r_a_1_key: (ctx) {
            ctx.replaceData<ImmutableData>(
                (current) => current.rebuild((b) => b
                  ..name = 'Jim'
                  ..price = 2),
                key: data_tree.r_a_key);
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(data_tree.r_a_1_key);

        await machine.processMessage(Object());

        DataProvider<ImmutableData> ancestorProvider =
            machine.nodes[data_tree.r_a_key].node.dataProvider();
        expect(ancestorProvider.data.name, equals('Jim'));
        expect(ancestorProvider.data.price, equals(2));
      });

      test('should throw if provider for data type cannot be found', () async {
        final buildTree = data_tree.treeBuilder(messageHandlers: {
          r_a_a_1_key: (ctx) {
            ctx.replaceData<String>((current) => current.toUpperCase());
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_a_1_key);

        expect(() => machine.processMessage(Object()), throwsStateError);
      });

      test('should throw if provider for key cannot be found', () async {
        final buildTree = data_tree.treeBuilder(messageHandlers: {
          r_a_a_1_key: (ctx) {
            ctx.replaceData<ImmutableData>((current) => current, key: r_a_a_2_key);
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_a_1_key);

        expect(() => machine.processMessage(Object()), throwsStateError);
      });
    });

    group('updateData', () {
      test('should update data in ancestor state', () async {
        final buildTree = data_tree.treeBuilder(messageHandlers: {
          data_tree.r_a_a_1_key: (ctx) {
            ctx.updateData<SpecialDataD>((current) {
              current.playerName = 'Jim';
              current.startYear = 2005;
            });
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(data_tree.r_a_a_1_key);

        await machine.processMessage(Object());

        DataProvider<SpecialDataD> ancestorProvider =
            machine.nodes[data_tree.r_key].node.dataProvider();
        expect(ancestorProvider.data.playerName, equals('Jim'));
        expect(ancestorProvider.data.startYear, equals(2005));
      });
    });

    group('post', () {
      test('Should send message', () async {
        final completer = Completer();
        var receivedMessage = false;
        final msg = Object();
        final msgToPost = Object();
        final buildTree = treeBuilder(
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, msg)) {
                ctx.post(msgToPost);
              } else if (identical(ctx.message, msgToPost)) {
                receivedMessage = true;
                completer.complete();
              }
              return ctx.stay();
            }
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await machine.processMessage(msg);
        await completer.future;

        expect(receivedMessage, isTrue);
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
        final machine = createMachine(buildTree);

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
        final machine = createMachine(buildTree);
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
        final machine = createMachine(buildTree);
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
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
        expect(machine.currentNode.key, equals(r_b_1_key));
      });
    });
  });

  group('MachineTransitionContext', () {
    group('data', () {
      test('should return data for handling state', () async {
        final dataByKey = <StateKey, Object>{};
        final buildTree = data_tree.treeBuilder(
          createEntryHandler: (key) => (ctx) {
            dataByKey[key] = ctx.data();
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState();

        expect(dataByKey[r_a_a_2_key], isA<LeafData2>());
        expect(dataByKey[r_a_a_key], isA<LeafDataBase>());
        expect(dataByKey[r_a_key], isA<ImmutableData>());
        expect(dataByKey[r_key], isA<SpecialDataD>());
      });
    });

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
        final machine = createMachine(buildTree);
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
        final machine = createMachine(buildTree);

        await machine.enterInitialState();
        await completer.future;

        expect(receivedMessage1, isTrue);
        expect(receivedMessage2, isTrue);
        expect(machine.currentNode.key, equals(r_b_1_key));
      });
    });

    group('schedule', () {
      test('should post messages when periodic is true', () async {
        final completer = Completer();
        var receiveCount = 0;
        Dispose dispose = null;
        final scheduledMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) {
              dispose = ctx.schedule(
                () => scheduledMsg,
                periodic: true,
                duration: Duration(milliseconds: 10),
              );
            }
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, scheduledMsg)) {
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
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
      });

      test('should be canceled when dispose function is called', () async {
        final completer = Completer();
        var receiveCount = 0;
        Dispose dispose = null;
        final scheduledMsg = Object();
        final completionMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) {
              dispose = ctx.schedule(
                () => scheduledMsg,
                periodic: true,
                duration: Duration(milliseconds: 10),
              );
            }
          },
          messageHandlers: {
            r_a_a_2_key: (ctx) {
              if (identical(ctx.message, scheduledMsg)) {
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
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
      });

      test('should be canceled when scheduling state is exited', () async {
        final completer = Completer();
        var receiveCount = 0;
        final scheduledMsg = Object();
        final completionMsg = Object();
        final buildTree = treeBuilder(
          entryHandlers: {
            r_a_a_key: (ctx) {
              ctx.schedule(
                () => scheduledMsg,
                periodic: true,
                duration: Duration(milliseconds: 10),
              );
            },
            r_b_1_key: (ctx) {
              // Schedule message that will finish the test in 50 milliseconds. That will give
              // enough time for the periodic messages scheduled in r_a_a state to arrive
              // (but they won't because timer should be canceled when exiting r_a_a)
              ctx.schedule(
                () => completionMsg,
                duration: Duration(milliseconds: 50),
              );
            }
          },
          messageHandlers: {
            r_a_a_key: (ctx) {
              if (identical(ctx.message, scheduledMsg)) {
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
              } else if (identical(ctx.message, completionMsg)) {
                completer.complete();
              }
              return ctx.unhandled();
            }
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await completer.future;

        expect(receiveCount, equals(3));
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
