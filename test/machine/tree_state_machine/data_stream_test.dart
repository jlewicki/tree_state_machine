// ignore_for_file: non_constant_identifier_names

import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import '../fixture/state_data.dart';
import '../fixture/data_tree.dart' as data_tree;

void main() {
  group('TreeStateMachine', () {
    group('dataStream', () {
      TreeStateMachine createStateMachine() =>
          TreeStateMachine(data_tree.treeBuilder(
            initialDataValues: {
              data_tree.r_a_a_key: () => LeafDataBase()..name = 'me',
              data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
            },
            messageHandlers: {
              data_tree.r_a_a_2_key: (msgCtx) {
                msgCtx
                    .data(data_tree.r_a_a_2_key)
                    .update((current) => current..label = 'not cool man');
                msgCtx
                    .data(data_tree.r_a_a_key)
                    .update((current) => current..name = 'you');
                return msgCtx.goTo(data_tree.r_a_a_1_key);
              },
              data_tree.r_a_a_1_key: (msgCtx) {
                msgCtx
                    .data(data_tree.r_a_a_key)
                    .update((current) => current..name = 'you!');
                return msgCtx.goTo(data_tree.r_a_a_2_key);
              }
            },
          ));

      for (var subscribeDynamic in [false, true]) {
        test(
            'should notify listeners if ${subscribeDynamic ? 'dynamic' : ''} '
            'subscribed before states are active', () async {
          final sm = createStateMachine();

          // State machine is started, so the states we listen to here are not yet active
          var r_a_a_2_stream = (subscribeDynamic
                  ? sm
                      .dataStream<dynamic>(data_tree.r_a_a_2_key)
                      .cast<LeafData2>()
                  : sm.dataStream(data_tree.r_a_a_2_key))
              .map((d) => d.label!);
          var r_a_a_2_queue = StreamQueue<String>(r_a_a_2_stream);
          var r_a_a_stream = (subscribeDynamic
                  ? sm
                      .dataStream<dynamic>(data_tree.r_a_a_key)
                      .cast<LeafDataBase>()
                  : sm.dataStream(data_tree.r_a_a_key))
              .map((d) => d.name!);
          var r_a_a_queue = StreamQueue<String>(r_a_a_stream);

          var currentState = await sm.start(at: data_tree.r_a_a_2_key);

          // Subscribers will be notified immediately of current values
          expect(currentState.key, equals(data_tree.r_a_a_2_key));
          expect(await r_a_a_2_queue.next, equals('cool'));
          expect(await r_a_a_queue.next, equals('me'));

          // Go to r_a_a_1
          await currentState.post(Object());
          expect(currentState.key, equals(data_tree.r_a_a_1_key));
          expect(await r_a_a_2_queue.next, equals('not cool man'));
          expect(await r_a_a_queue.next, equals('you'));

          // Go to r_a_a_2
          await currentState.post(Object());
          expect(currentState.key, equals(data_tree.r_a_a_2_key));
          // We entered r_a_a_2 (again), so a new data value was created, so it pushed its value
          // of 'cool' immediately to the r_a_a_2_stream subscription (because value subjects
          // notify immediately on subscribe)
          expect(await r_a_a_2_queue.next, equals('cool'));
          expect(await r_a_a_queue.next, equals('you!'));

          // Go to r_a_a_1
          await currentState.post(Object());
          expect(currentState.key, equals(data_tree.r_a_a_1_key));
          expect(await r_a_a_2_queue.next, equals('not cool man'));
          expect(await r_a_a_queue.next, equals('you'));
        });
      }

      test('should notify listeners if subscribed while states are active',
          () async {
        final sm = createStateMachine();

        var currentState = await sm.start(at: data_tree.r_a_a_2_key);

        // State machine is started, so the states we listen to here are active
        var r_a_a_2_stream = sm
            .dataStream<LeafData2>(data_tree.r_a_a_2_key)
            .map((d) => d.label!);
        var r_a_a_2_queue = StreamQueue<String>(r_a_a_2_stream);
        var r_a_a_stream = sm
            .dataStream<LeafDataBase>(data_tree.r_a_a_key)
            .map((d) => d.name!);
        var r_a_a_queue = StreamQueue<String>(r_a_a_stream);

        // Subscribers will be notified immediately of current values
        expect(currentState.key, equals(data_tree.r_a_a_2_key));
        expect(await r_a_a_2_queue.next, equals('cool'));
        expect(await r_a_a_queue.next, equals('me'));

        // Go to r_a_a_1
        await currentState.post(Object());
        expect(currentState.key, equals(data_tree.r_a_a_1_key));
        expect(await r_a_a_2_queue.next, equals('not cool man'));
        expect(await r_a_a_queue.next, equals('you'));

        // Go to r_a_a_2
        await currentState.post(Object());
        expect(currentState.key, equals(data_tree.r_a_a_2_key));
        // We entered r_a_a_2 (again), so a new data value was created, so it pushed its value
        // of 'cool' immediately to the r_a_a_2_stream subscription (because value subjects
        // notify immediately on subscribe)
        expect(await r_a_a_2_queue.next, equals('cool'));
        expect(await r_a_a_queue.next, equals('you!'));

        // Go to r_a_a_1
        await currentState.post(Object());
        expect(currentState.key, equals(data_tree.r_a_a_1_key));
        expect(await r_a_a_2_queue.next, equals('not cool man'));
        expect(await r_a_a_queue.next, equals('you'));
      });

      test('should notify listeners if subscribed after states are active',
          () async {
        final sm = TreeStateMachine(data_tree.treeBuilder(
          initialDataValues: {
            data_tree.r_a_a_key: () => LeafDataBase()..name = 'me',
            data_tree.r_a_a_2_key: () => LeafData2()..label = 'cool'
          },
          messageHandlers: {
            data_tree.r_a_a_2_key: (msgCtx) {
              if (msgCtx.message is _GoToMessage) {
                msgCtx
                    .data(data_tree.r_a_a_2_key)
                    .update((current) => current..label = 'not cool man');
                msgCtx
                    .data(data_tree.r_a_a_key)
                    .update((current) => current..name = 'you');
                return msgCtx.goTo((msgCtx.message as _GoToMessage).state);
              }
              return msgCtx.unhandled();
            },
            data_tree.r_a_a_1_key: (msgCtx) {
              msgCtx
                  .data(data_tree.r_a_a_key)
                  .update((current) => current..name = 'you!');
              return msgCtx.goTo(data_tree.r_a_a_2_key);
            },
            data_tree.r_b_1_key: (msgCtx) {
              return msgCtx.goTo(data_tree.r_a_a_2_key);
            }
          },
        ));

        var currentState = await sm.start(at: data_tree.r_a_a_2_key);
        await currentState.post(_GoToMessage(data_tree.r_b_1_key));

        // State machine is started, but in state r_b_1, so the states we subscribe to here are
        // no longer active
        var r_a_a_2_stream = sm
            .dataStream<LeafData2>(data_tree.r_a_a_2_key)
            .map((d) => d.label!);
        var r_a_a_2_queue = StreamQueue<String>(r_a_a_2_stream);
        var r_a_a_stream = sm
            .dataStream<LeafDataBase>(data_tree.r_a_a_key)
            .map((d) => d.name!);
        var r_a_a_queue = StreamQueue<String>(r_a_a_stream);

        await currentState.post(Object());

        // Subscribers will be notified immediately of current values
        expect(currentState.key, equals(data_tree.r_a_a_2_key));
        expect(await r_a_a_2_queue.next, equals('cool'));
        expect(await r_a_a_queue.next, equals('me'));

        // Go to r_a_a_1
        await currentState.post(_GoToMessage(data_tree.r_a_a_1_key));
        expect(currentState.key, equals(data_tree.r_a_a_1_key));
        expect(await r_a_a_2_queue.next, equals('not cool man'));
        expect(await r_a_a_queue.next, equals('you'));

        // Go to r_a_a_2
        await currentState.post(Object());
        expect(currentState.key, equals(data_tree.r_a_a_2_key));
        // We entered r_a_a_2 (again), so a new data value was created, so it pushed its initial value
        // of 'cool' immediately to the r_a_a_2_stream subscription (because value subjects
        // notify immediately on subscribe)
        expect(await r_a_a_2_queue.next, equals('cool'));
        expect(await r_a_a_queue.next, equals('you!'));

        // Go to r_a_a_1
        await currentState.post(_GoToMessage(data_tree.r_a_a_1_key));
        expect(currentState.key, equals(data_tree.r_a_a_1_key));
        expect(await r_a_a_2_queue.next, equals('not cool man'));
        expect(await r_a_a_queue.next, equals('you'));
      });
    });
  });
}

class _GoToMessage {
  final StateKey state;
  _GoToMessage(this.state);
}
