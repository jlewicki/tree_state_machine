// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'fixture/fixture_util.dart';
import 'fixture/data_tree.dart';
import 'fixture/state_data.dart';

void main() {
  group('MachineTransitionContext', () {
    group('lca', () {
      test('should return least common ancestor for transition', () async {
        final lcaByKey = <StateKey, StateKey?>{};
        final buildTree = treeBuilder(
            createEntryHandler: (key) => (ctx) {
                  lcaByKey[key] = ctx.lca;
                },
            createExitHandler: (key) => (ctx) {
                  lcaByKey[key] = ctx.lca;
                },
            messageHandlers: {
              r_b_1_key: (ctx) => ctx.goTo(r_a_a_2_key),
            });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_b_1_key);
        await machine.processMessage(Object());

        expect(lcaByKey[r_a_a_2_key], equals(r_key));
        expect(lcaByKey[r_a_a_key], equals(r_key));
        expect(lcaByKey[r_a_key], equals(r_key));
        expect(lcaByKey[r_b_key], equals(r_key));
        expect(lcaByKey[r_b_1_key], equals(r_key));
      });
    });

    group('data', () {
      test('should return data for handling state', () async {
        final dataByKey = <StateKey, Object?>{};
        final buildTree = treeBuilder(
            createEntryHandler: (key) => (ctx) {
                  dataByKey[key] =
                      key is DataStateKey<dynamic> ? ctx.data<dynamic>(key)?.value : null;
                },
            createExitHandler: (key) => (ctx) {
                  key is DataStateKey<dynamic> ? ctx.data<dynamic>(key)?.value : null;
                },
            messageHandlers: {
              r_b_1_key: (ctx) => ctx.goTo(r_a_a_2_key),
            });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_b_1_key);
        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_2_key], isA<LeafData2>());
        expect(dataByKey[r_a_a_key], isA<LeafDataBase>());
        expect(dataByKey[r_a_key], isA<ImmutableData>());
        expect(dataByKey[r_b_key], isNull);
        expect(dataByKey[r_b_1_key], isNull);
      });
    });

    group('post', () {
      test('Should send message to end state when transition completes', () async {
        final completer = Completer<void>();
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
        final completer = Completer<void>();
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
        expect(machine.currentLeaf!.key, equals(r_b_1_key));
      });
    });

    group('schedule', () {
      test('should post messages when periodic is true', () async {
        final completer = Completer<void>();
        var receiveCount = 0;
        Dispose? dispose;
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
                  dispose!();
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
        final completer = Completer<void>();
        var receiveCount = 0;
        Dispose? dispose;
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
                  dispose!();
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
        final completer = Completer<void>();
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
        expect(machine.currentLeaf!.key, equals(r_b_1_key));
      });
    });
  });
}
