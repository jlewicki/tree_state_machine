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
        currentState.dataValue<int>();
        expect(currentState.dataValue<int>(), equals(2));
      });
    });
  });
}
