import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'fixture/fixture_data.dart';

final state1 = StateKey('state1');
final dataState1 = DataStateKey<int>('state1');

void main() {
  group('MessageActionBuilder', () {
    group('run', () {
      test('should run action', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: state1);
        Message? messageFromAction;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2,
              action: b.act.run((ctx) => messageFromAction = ctx.message)));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(messageFromAction, equals(msg));
      });
    });

    group('updateData', () {
      test('should update data', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: dataState1);
        b.dataState<int>(dataState1, InitialData(() => 1), (b) {
          b.onMessage<Message>((b) =>
              b.stay(action: b.act.updateOwnData((ctx) => ctx.data + 1)));
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.dataValue(dataState1), equals(2));
      });
    });

    group('post', () {
      test('should post message', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: state1);
        b.state(state1, (b) {
          b.onMessage<Message>(
              (b) => b.stay(action: b.act.post(message: Message2())));
          b.onMessage<Message2>((b) => b.goTo(state2));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.key, equals(state2));
      });
    });

    group('schedule', () {
      test('should schedule message', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.stay(
              action: b.act.schedule(
                  message: Message2(), duration: Duration(milliseconds: 20))));
          b.onMessage<Message2>((b) => b.goTo(state2));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.key, equals(state1));
        await Future<void>.delayed(Duration(milliseconds: 30));
        expect(currentState.key, equals(state2));
      });
    });
  });

  group('MessageActionBuilderWithData', () {
    group('run', () {
      test('should run action', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: dataState1);
        Message? messageFromAction;
        int? dataFromAction;
        b.dataState<int>(dataState1, InitialData(() => 2), (b) {
          b.onMessage<Message>((b) => b.goTo(state2, action: b.act.run(
                (ctx) {
                  messageFromAction = ctx.message;
                  dataFromAction = ctx.data;
                },
              )));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(messageFromAction, equals(msg));
        expect(dataFromAction, equals(2));
      });
    });

    group('updateData', () {
      test('should update data', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: dataState1);
        b.dataState<int>(dataState1, InitialData(() => 1), (b) {
          b.onMessage<Message>((b) =>
              b.stay(action: b.act.updateOwnData((ctx) => ctx.data + 1)));
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.dataValue(dataState1), equals(2));
      });
    });

    group('post', () {
      test('should post message', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: dataState1);
        Message? messageFromAction;
        int? dataFromAction;
        b.dataState<int>(dataState1, InitialData(() => 2), (b) {
          b.onMessage<Message>((b) => b.stay(action: b.act.post(
                getMessage: (ctx) {
                  messageFromAction = ctx.message;
                  dataFromAction = ctx.data;
                  return Message2();
                },
              )));
          b.onMessage<Message2>((b) => b.goTo(state2));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(messageFromAction, equals(msg));
        expect(dataFromAction, equals(2));
        expect(currentState.key, equals(state2));
      });
    });

    group('schedule', () {
      test('should schedule message', () async {
        var b = DeclarativeStateTreeBuilder(initialChild: dataState1);
        Message? messageFromAction;
        int? dataFromAction;
        b.dataState<int>(dataState1, InitialData(() => 2), (b) {
          b.onMessage<Message>((b) => b.stay(
                action: b.act.schedule(
                  getMessage: (ctx) {
                    messageFromAction = ctx.message;
                    dataFromAction = ctx.data;
                    return Message2();
                  },
                  duration: Duration(milliseconds: 20),
                ),
              ));
          b.onMessage<Message2>((b) => b.goTo(state2));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);

        expect(currentState.key, equals(dataState1));
        await Future<void>.delayed(Duration(milliseconds: 30));
        expect(messageFromAction, equals(msg));
        expect(dataFromAction, equals(2));
        expect(currentState.key, equals(state2));
      });
    });
  });
}
