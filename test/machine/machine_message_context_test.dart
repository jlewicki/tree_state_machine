// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'fixture/fixture_util.dart';
import 'fixture/data_tree.dart';
import 'fixture/state_data.dart';
import 'fixture/tree.dart' as tree;

void main() {
  group('MachineMessageContext', () {
    group('data', () {
      test('should return data for handling state', () async {
        final dataByKey = <StateKey, dynamic>{};
        final buildTree = treeBuilder(
          createMessageHandler: (key) => (ctx) {
            dataByKey[key] = ctx.data(key)!.value;
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

      test('should return data for state referenced by key', () async {
        final dataByKey = <StateKey, dynamic>{};
        final buildTree = treeBuilder(
          createMessageHandler: (key) => (ctx) {
            // Look up data for ancestor state
            if (key == r_a_a_2_key || key == r_a_a_key) {
              dataByKey[key] = ctx.data(r_a_key)!.value;
            }

            return ctx.unhandled();
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_2_key], isA<ImmutableData>());
        expect(dataByKey[r_a_a_key], isA<ImmutableData>());
      });

      test('should return null if handling state has no data', () async {
        final dataByKey = <StateKey, Object?>{};
        final buildTree = tree.treeBuilder(
          createMessageHandler: (key) => (ctx) {
            dataByKey[key] = ctx.data()?.value;
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
        final dataByKey = <StateKey, Object?>{};
        final buildTree = treeBuilder(messageHandlers: {
          r_a_a_key: (ctx) {
            dataByKey[r_a_a_key] = ctx.data(r_a_a_2_key)?.value;
            return ctx.unhandled();
          },
          r_a_key: (ctx) {
            dataByKey[r_a_key] = ctx.data(r_a_a_key)?.value;
            return ctx.unhandled();
          }
        });

        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await machine.processMessage(Object());

        expect(dataByKey[r_a_a_key], isNull);
        expect(dataByKey[r_a_key], isNull);
      });

      test('should throw whem updating after state is exited', () async {
        DataValue<LeafData2>? dataVal;
        var buildTree = treeBuilder(
          initialDataValues: {r_a_a_2_key: () => LeafData2()..label = 'cool'},
          messageHandlers: {
            r_a_a_2_key: (msgCtx) {
              dataVal = msgCtx.data<LeafData2>();
              return msgCtx.goTo(r_a_a_1_key);
            },
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState();
        await machine.processMessage(Object());

        expect(dataVal, isNotNull);
        expect(() => dataVal!.update((current) => current..label = 'not cool'), throwsStateError);
      });
    });

    group('updateData', () {
      test('should replace data in ancestor state', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_a_a_1_key: (ctx) {
            ctx.updateOrThrow<ImmutableData>((_) => ImmutableData(name: 'Jim', price: 2));
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_a_1_key);

        await machine.processMessage(Object());

        var data = machine.nodes[r_a_key]!.treeNode.data as DataValue<ImmutableData>;
        expect(data.value.name, equals('Jim'));
        expect(data.value.price, equals(2));
      });

      test('should replace data in closest state', () async {
        final r_a_data = ImmutableData(name: 'John', price: 10);
        final r_a_1_data = ImmutableData(name: 'Pete', price: 5);

        final buildTree = treeBuilder(
          initialDataValues: {
            r_a_key: () => r_a_data,
            r_a_1_key: () => r_a_1_data,
          },
          messageHandlers: {
            r_a_1_key: (ctx) {
              ctx.updateOrThrow<ImmutableData>((_) => ImmutableData(name: 'Jim', price: 2));
              return ctx.stay();
            }
          },
        );
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_1_key);

        await machine.processMessage(Object());

        var data = machine.nodes[r_a_1_key]!.treeNode.data as DataValue<ImmutableData>;
        expect(data.value.name, equals('Jim'));
        expect(data.value.price, equals(2));

        var ancestorData = machine.nodes[r_a_key]!.treeNode.data as DataValue<ImmutableData>;
        expect(ancestorData.value, same(r_a_data));
      });

      test('should replace data in ancestor state by key', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_a_1_key: (ctx) {
            ctx.updateOrThrow<ImmutableData>((_) => ImmutableData(name: 'Jim', price: 2),
                key: r_a_key);
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_1_key);

        await machine.processMessage(Object());

        var ancestorData = machine.nodes[r_a_key]!.treeNode.data as DataValue<ImmutableData>;
        expect(ancestorData.value.name, equals('Jim'));
        expect(ancestorData.value.price, equals(2));
      });

      test('should throw if provider for data type cannot be found', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_a_a_1_key: (ctx) {
            ctx.updateOrThrow<String>((current) => current.toUpperCase());
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_a_1_key);

        expect(() => machine.processMessage(Object()), throwsStateError);
      });

      test('should throw if provider for key cannot be found', () async {
        final buildTree = treeBuilder(messageHandlers: {
          r_a_a_1_key: (ctx) {
            ctx.updateOrThrow<ImmutableData>((current) => current, key: r_a_a_2_key);
            return ctx.stay();
          }
        });
        final machine = createMachine(buildTree);
        await machine.enterInitialState(r_a_a_1_key);

        expect(() => machine.processMessage(Object()), throwsStateError);
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
        Dispose? dispose;
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
        final completer = Completer();
        var receiveCount = 0;
        Dispose? dispose;
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
        expect(machine.currentLeaf!.key, equals(r_b_1_key));
      });
    });
  });
}
