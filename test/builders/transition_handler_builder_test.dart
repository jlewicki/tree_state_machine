import 'package:test/test.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

class StateData {
  String val = '0';
}

class Message {
  String val = 'msg';
}

void main() {
  final rootState = StateKey('root');
  final state1 = StateKey('s1');
  final state2 = StateKey('s2');
  final state3 = StateKey('s3');
  group('TransitionHandlerBuilderWithPayload', () {
    group('updateData', () {
      test('should update data from payload', () async {
        var s3Channel = Channel<String>(state3);
        var b = StateTreeBuilder.withDataRoot<StateData>(
            rootState, InitialData(() => StateData()), emptyDataState, InitialChild(state1));
        b.state(state1, (b) {
          b.onMessage<Message>((b) {
            b.enterChannel(s3Channel, (_, msg) => msg.val, reenterTarget: true);
          });
        }, initialChild: InitialChild(state2));
        b.state(state2, emptyState, parent: state1);
        b.state(state3, (b) {
          b.onEnterFromChannel<String>(s3Channel, (b) {
            b.updateData<StateData>((transCtx, current, payload) => current..val = payload);
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message()..val = '1');
        expect(currentState.key, equals(state3));
        expect(currentState.dataValue<StateData>()!.val, equals('1'));
      });
    });
  });
}
