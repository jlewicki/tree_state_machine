import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'fixture/fixture_data.dart';

final state2 = DataStateKey<StateData>('state2');
final state3 = DataStateKey<StateData2>('state3');

void main() {
  group('InitialData', () {
    group('fromChannel', () {
      test('should initialize data from channel payload', () async {
        var channel = EntryChannel<String>(state2);
        StateData? entryData;

        var b = DeclarativeStateTreeBuilder(initialChild: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.enterChannel(channel, (_) => 'hi'));
        });
        b.dataState<StateData>(
          state2,
          channel.initialData((payload) => StateData()..val = payload),
          (b) {
            b.onEnter((b) => b.run((ctx) => entryData = ctx.data));
          },
        );

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());

        expect(currentState.key, equals(state2));
        expect(entryData, isNotNull);
        expect(entryData!.val, equals('hi'));
      });
    });

    group('fromAncestor', () {
      test('should initialize data from ancestor state data', () async {
        StateData2? entryData;

        var b = DeclarativeStateTreeBuilder(initialChild: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
        });
        b.dataState<StateData>(
          state2,
          InitialData(() => StateData()..val = '2'),
          emptyState,
          initialChild: InitialChild(state3),
        );
        b.dataState<StateData2>(
          state3,
          InitialData.fromAncestor(
            state2,
            (ancData) => StateData2()..val = int.parse(ancData.val),
          ),
          (b) {
            b.onEnter((b) => b.run((ctx) => entryData = ctx.data));
          },
          parent: state2,
        );

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());

        expect(currentState.key, equals(state3));
        expect(entryData, isNotNull);
        expect(entryData!.val, equals(2));
      });
    });

    group('fromChannelAndAncestor', () {
      test('should initialize data from channel payload ancestor state data',
          () async {
        StateData2? entryData;
        var channel = EntryChannel<String>(state3);

        var b = DeclarativeStateTreeBuilder(initialChild: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.enterChannel(channel, (_) => '3'));
        });
        b.dataState<StateData>(
          state2,
          InitialData(() => StateData()..val = '2'),
          emptyState,
          initialChild: InitialChild(state3),
        );
        b.dataState<StateData2>(
          state3,
          channel.initialDataFromAncestor(
            state2,
            (StateData ancData, String payload) =>
                StateData2()..val = int.parse(ancData.val + payload),
          ),
          (b) {
            b.onEnter((b) => b.run((ctx) => entryData = ctx.data));
          },
          parent: state2,
        );

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());

        expect(currentState.key, equals(state3));
        expect(entryData, isNotNull);
        expect(entryData!.val, equals(23));
      });
    });
  });
}
