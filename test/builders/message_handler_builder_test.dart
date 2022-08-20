import 'package:test/test.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'fixture/fixture_data.dart';

void main() {
  group('MessageActionBuilder', () {
    group('goTo', () {
      test('should go to target state', () async {
        var b = StateTreeBuilder(initialState: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(currentState.key, equals(state2));
      });
    });

    group('enterChannel', () {
      test('should go to target state with payload from channel', () async {
        var s2Channel = Channel<String>(state2);

        var b = StateTreeBuilder(initialState: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) {
            b.enterChannel(s2Channel, (ctx) => ctx.message.val);
          });
        });
        b.dataState<String>(state2, InitialData(() => '1'), (b) {
          b.onEnterFromChannel<String>(s2Channel, (b) {
            b.updateOwnData((ctx) => ctx.context);
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message()..val = '2';

        await currentState.post(msg);

        expect(currentState.key, equals(state2));
        expect(currentState.dataValue<String>(), equals('2'));
      });

      test('should run action before transition', () async {
        var s2Channel = Channel<String>(state2);

        var actionWasRun = false;
        var b = StateTreeBuilder(initialState: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) {
            b.enterChannel(s2Channel, (ctx) => ctx.message.val,
                action: b.act.run((_) => actionWasRun = true));
          });
        });
        b.dataState<String>(state2, InitialData(() => '1'), (b) {
          b.onEnterFromChannel<String>(s2Channel, (b) {
            b.updateOwnData((ctx) => ctx.context);
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message()..val = '2';

        await currentState.post(msg);

        expect(currentState.key, equals(state2));
        expect(currentState.dataValue<String>(), equals('2'));
        expect(actionWasRun, isTrue);
      });
    });
  });
}
