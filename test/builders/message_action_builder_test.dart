import 'package:test/test.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'fixture/fixture_data.dart';

void main() {
  group('MessageActionBuilder', () {
    group('run', () {
      test('should run action', () async {
        var b = StateTreeBuilder(initialState: state1);
        Message? messageFromAction;
        b.state(state1, (b) {
          b.onMessage<Message>(
              (b) => b.goTo(state2, action: b.act.run((msgCtx, msg) => messageFromAction = msg)));
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
        var b = StateTreeBuilder(initialState: state1);
        b.dataState<int>(state1, InitialData(() => 1), (b) {
          b.onMessage<Message>(
              (b) => b.stay(action: b.act.updateData((msgCtx, msg, current) => current + 1)));
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.dataValue<int>(), equals(2));
      });
    });

    group('post', () {
      test('should post message', () async {
        var b = StateTreeBuilder(initialState: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.stay(action: b.act.post(message: Message2())));
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
        var b = StateTreeBuilder(initialState: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.stay(
              action: b.act.schedule(message: Message2(), duration: Duration(milliseconds: 20))));
          b.onMessage<Message2>((b) => b.goTo(state2));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.key, equals(state1));
        await Future.delayed(Duration(milliseconds: 30));
        expect(currentState.key, equals(state2));
      });
    });
  });

  group('MessageActionBuilderWithData', () {
    group('run', () {
      test('should run action', () async {
        var b = StateTreeBuilder(initialState: state1);
        Message? messageFromAction;
        int? dataFromAction;
        b.dataState<int>(state1, InitialData(() => 2), (b) {
          b.onMessage<Message>((b) => b.goTo(state2, action: b.act.run(
                (msgCtx, msg, data) {
                  messageFromAction = msg;
                  dataFromAction = data;
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
        var b = StateTreeBuilder(initialState: state1);
        b.dataState<int>(state1, InitialData(() => 1), (b) {
          b.onMessage<Message>(
              (b) => b.stay(action: b.act.updateData((msgCtx, msg, current) => current + 1)));
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        currentState.dataValue<int>();
        expect(currentState.dataValue<int>(), equals(2));
      });
    });

    group('post', () {
      test('should post message', () async {
        var b = StateTreeBuilder(initialState: state1);
        Message? messageFromAction;
        int? dataFromAction;
        b.dataState<int>(state1, InitialData(() => 2), (b) {
          b.onMessage<Message>((b) => b.stay(action: b.act.post(
                getMessage: (_, msg, data) {
                  messageFromAction = msg;
                  dataFromAction = data;
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
        var b = StateTreeBuilder(initialState: state1);
        Message? messageFromAction;
        int? dataFromAction;
        b.dataState<int>(state1, InitialData(() => 2), (b) {
          b.onMessage<Message>((b) => b.stay(
                action: b.act.schedule(
                  getMessage: (_, msg, data) {
                    messageFromAction = msg;
                    dataFromAction = data;
                    return () => Message2();
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

        expect(currentState.key, equals(state1));
        await Future.delayed(Duration(milliseconds: 30));
        expect(messageFromAction, equals(msg));
        expect(dataFromAction, equals(2));
        expect(currentState.key, equals(state2));
      });
    });
  });
}
