import 'package:test/test.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'fixture/fixture_data.dart';

final state2 = DataStateKey<String>('state2');

void main() {
  group('MessageActionBuilder', () {
    group('goTo', () {
      test('should go to target state', () async {
        var b = StateTreeBuilder(initialChild: state1);
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

    group('action', () {
      test('should execute action and stay in current state', () async {
        var wasRun = false;
        var b = StateTreeBuilder(initialChild: state1);
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.action(b.act.run((ctx) => wasRun = true)));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(currentState.key, equals(state1));
        expect(wasRun, isTrue);
      });

      test('should execute action and dispatch to parent state when unhandled', () async {
        var wasRun1 = false;
        var wasRun2 = false;

        var b = StateTreeBuilder.withRoot(rootState, emptyState, InitialChild(state1));
        b.state(
          state1,
          (b) {
            b.onMessage<Message>((b) => b.action(b.act.run((ctx) => wasRun1 = true)));
          },
          initialChild: InitialChild(state2),
        );
        b.state(
          state2,
          (b) {
            b.onMessage<Message>(
                (b) => b.action(b.act.run((ctx) => wasRun2 = true), ActionResult.unhandled));
          },
          parent: state1,
        );

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(currentState.key, equals(state2));
        expect(wasRun1, isTrue);
        expect(wasRun2, isTrue);
      });
    });

    group('unhandled', () {
      test('should execute action and dispatch to parent state', () async {
        var wasRun1 = false;
        var wasRun2 = false;

        var b = StateTreeBuilder.withRoot(rootState, emptyState, InitialChild(state1));
        b.state(
          state1,
          (b) {
            b.onMessage<Message>((b) => b.action(b.act.run((ctx) => wasRun1 = true)));
          },
          initialChild: InitialChild(state2),
        );
        b.state(
          state2,
          (b) {
            b.onMessage<Message>((b) => b.unhandled(action: b.act.run((ctx) => wasRun2 = true)));
          },
          parent: state1,
        );

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message();
        await currentState.post(msg);
        expect(currentState.key, equals(state2));
        expect(wasRun1, isTrue);
        expect(wasRun2, isTrue);
      });
    });

    group('when', () {
      var b = StateTreeBuilder(initialChild: state1);
      b.state(state1, (b) {
        b.onMessage<Message>((b) => b
            .when((ctx) => ctx.message.val == "2", (b) => b.goTo(state2))
            .when((ctx) => ctx.message.val == "3", (b) => b.goTo(state3))
            .when((ctx) => ctx.message.val.startsWith("3"), (b) => b.goTo(state4))
            .otherwise((b) => b.goTo(state5)));
      });
      b.state(state2, emptyState);
      b.state(state3, emptyState);
      b.state(state4, emptyState);
      b.state(state5, emptyState);

      test('should evaluate conditions and use handler of first match', () async {
        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message()..val = "3";
        await currentState.post(msg);
        expect(currentState.key, equals(state3));
      });

      test('should use otherwise handler when no match', () async {
        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        var msg = Message()..val = "no match";
        await currentState.post(msg);
        expect(currentState.key, equals(state5));
      });
    });

    group('enterChannel', () {
      test('should go to target state with payload from channel', () async {
        var s2Channel = Channel<String>(state2);

        var b = StateTreeBuilder(initialChild: state1);
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
        var b = StateTreeBuilder(initialChild: state1);
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
