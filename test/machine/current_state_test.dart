// ignore_for_file: non_constant_identifier_names

import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'fixture/state_data.dart';
import 'fixture/tree.dart' as tree;
import 'fixture/data_tree.dart' as data_tree;

void main() {
  group('CurrentState', () {
    group('key', () {
      test('should return initial state after starting', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start();

        expect(currentState.key, equals(tree.initialStateKey));
      });

      test('should return current state after transition', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.initialStateKey: (msgCtx) => msgCtx.goTo(tree.r_b_1_key),
        }));
        var currentState = await sm.start();

        await currentState.post(Object());

        expect(currentState.key, equals(tree.r_b_1_key));
      });
    });

    group('sendMessage', () {
      test('should dispatch to state machine for processing', () async {
        final sm = TreeStateMachine(tree.treeBuilder(messageHandlers: {
          tree.initialStateKey: (msgCtx) => msgCtx.stay(),
        }));
        var currentState = await sm.start();

        var msg = Object();
        var result = await currentState.post(msg);

        expect(result, isA<HandledMessage>());
        final handled = result as HandledMessage;
        expect(handled.message, same(msg));
        expect(handled.receivingState, equals(tree.r_a_a_2_key));
      });

      test('should queue messages', () async {
        final msg1 = Object();
        final msg2 = Object();
        final msg3 = Object();
        final sm = TreeStateMachine(tree.treeBuilder(
          messageHandlers: {
            tree.r_a_a_2_key: (msgCtx) => msgCtx.message == msg1
                ? msgCtx.goTo(tree.r_a_a_1_key)
                : msgCtx.unhandled(),
            tree.r_a_a_1_key: (msgCtx) => msgCtx.message == msg2
                ? msgCtx.goTo(tree.r_b_1_key)
                : msgCtx.unhandled(),
            tree.r_b_1_key: (msgCtx) => msgCtx.message == msg3
                ? msgCtx.goTo(tree.r_b_2_key)
                : msgCtx.unhandled(),
          },
        ));
        var currentState = await sm.start();

        final msg1Future = currentState.post(msg1);
        final msg2Future = currentState.post(msg2);
        final msg3Future = currentState.post(msg3);

        await Future.wait([msg1Future, msg2Future, msg3Future]);
        expect(currentState.key, equals(tree.r_b_2_key));

        var result = await msg1Future;
        expect(result, isA<HandledMessage>());
        var handled = result as HandledMessage;
        expect(handled.receivingState, equals(tree.r_a_a_2_key));
        expect(handled.transition, isNotNull);
        expect(handled.transition!.to, equals(tree.r_a_a_1_key));

        result = await msg2Future;
        expect(result, isA<HandledMessage>());
        handled = result as HandledMessage;
        expect(handled.receivingState, equals(tree.r_a_a_1_key));
        expect(handled.transition!.to, equals(tree.r_b_1_key));

        result = await msg3Future;
        expect(result, isA<HandledMessage>());
        handled = result as HandledMessage;
        expect(handled.receivingState, equals(tree.r_b_1_key));
        expect(handled.transition, isNotNull);
        expect(handled.transition!.to, equals(tree.r_b_2_key));
      });
    });

    group('isActiveState', () {
      test('should return true for current state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start();

        expect(currentState.isInState(tree.initialStateKey), isTrue);
      });

      test('should return true for ancestor of current state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start();

        expect(currentState.isInState(tree.r_a_key), isTrue);
      });

      test('should return false for non-ancestor of current state', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start();

        expect(currentState.isInState(tree.r_b_key), isFalse);
      });
    });

    group('dataValue', () {
      test('should return data for current state by type', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
          },
        ));
        var currentState = await sm.start(at: data_tree.r_a_a_2_key);

        final data = currentState.dataValue<LeafData2>();
        expect(data, isNotNull);
        expect(data!.label, equals('cool'));
      });

      test('should return data for ancestor state by type', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_c_key: () => ReadOnlyData('r_c_key', 1),
            data_tree.r_c_a_key: () => ReadOnlyData('r_c_a_key', 2)
          },
        ));
        var currentState = await sm.start(at: data_tree.r_c_a_1_key);

        // Since we only specify type, we find state data of nearest ancestor
        final data = currentState.dataValue<ReadOnlyData>();
        expect(data, isNotNull);
        expect(data!.name, equals('r_c_a_key'));
      });

      test('should return data for ancestor state by key', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_c_key: () => ReadOnlyData('r_c_key', 1),
            data_tree.r_c_a_key: () => ReadOnlyData('r_c_a_key', 2)
          },
        ));
        var currentState = await sm.start(at: data_tree.r_c_a_1_key);

        // Since we only specify key, we find state data of that specific state
        final data = currentState.dataValue<ReadOnlyData>(data_tree.r_c_key);
        expect(data, isNotNull);
        expect(data!.name, equals('r_c_key'));
      });

      test('should return leaf data value if data type is unspecified',
          () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
          },
        ));
        var currentState = await sm.start(at: data_tree.r_a_a_2_key);
        var data = currentState.dataValue<dynamic>();
        expect(data, isNotNull);
        expect(data!.label, equals('cool'));
      });

      test(
          'should return null if data type is unspecified and leaf has no state data',
          () async {
        final sm = TreeStateMachine(data_tree.treeBuilder());
        var currentState = await sm.start(at: data_tree.r_b_1_key);
        var data = currentState.dataValue<dynamic>();
        expect(data, isNull);
      });

      test('should return null when data type cannot be resolved', () async {
        final sm = TreeStateMachine(tree.treeBuilder());
        var currentState = await sm.start();
        expect(currentState.dataValue<ReadOnlyData>(), isNull);
      });
    });
    group('data', () {
      test('should notify listeners when data is updated', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
          },
          messageHandlers: {
            data_tree.r_a_a_2_key: (msgCtx) {
              msgCtx
                  .data(data_tree.r_a_a_2_key)!
                  .update((current) => current..label = 'not cool man');
              return msgCtx.unhandled();
            }
          },
        ));
        var currentState = await sm.start(at: data_tree.r_a_a_2_key);

        LeafData2? nextValue;
        currentState
            .dataStream<LeafData2>()!
            .listen((value) => nextValue = value);
        await currentState.post(Object());

        expect(nextValue, isNotNull);
        expect(nextValue!.label, 'not cool man');
      });

      test('should complete subscription when state is exited', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
          },
          messageHandlers: {
            data_tree.r_a_a_2_key: (msgCtx) => msgCtx.goTo(data_tree.r_b_2_key),
          },
        ));
        var currentState = await sm.start(at: data_tree.r_a_a_2_key);

        var isDone_r_a_a_2 = false;
        var subscription_r_a_a_2 = currentState
            .dataStream<LeafData2>()!
            .listen(null, onDone: () => isDone_r_a_a_2 = true);

        var isDone_r_a_a = false;
        var subscription_r_a_a = currentState
            .dataStream<LeafDataBase>(data_tree.r_a_a_key)!
            .listen(null, onDone: () => isDone_r_a_a = true);

        var isDone_r_a = false;
        var subscription_r_a = currentState
            .dataStream<ImmutableData>(data_tree.r_a_key)!
            .listen(null, onDone: () => isDone_r_a = true);

        expect(subscription_r_a_a_2, isNotNull);
        expect(subscription_r_a_a, isNotNull);
        expect(subscription_r_a, isNotNull);

        await currentState.post(Object());

        expect(isDone_r_a_a_2, isTrue);
        expect(isDone_r_a_a, isTrue);
        expect(isDone_r_a, isTrue);
      });

      test('should return null if requested state data is not active',
          () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
          },
          messageHandlers: {
            data_tree.r_a_a_1_key: (msgCtx) =>
                msgCtx.goTo(data_tree.r_a_a_2_key),
          },
        ));
        var currentState = await sm.start(at: data_tree.r_a_a_2_key);

        var subscription = currentState.dataStream<String>()?.listen(null);

        expect(subscription, isNull);
      });

      test('should return null DataValue for non-data states', () async {
        final sm = TreeStateMachine(data_tree.treeBuilder());
        var currentState = await sm.start(at: data_tree.r_b_2_key);

        var r_b_2_data = currentState.dataStream<int>();
        expect(r_b_2_data, isNotNull);
        expect(r_b_2_data!.value, equals(2));

        var r_b_data = currentState.dataStream<void>();
        expect(r_b_data, isNull);
      });
    });
  });
}
