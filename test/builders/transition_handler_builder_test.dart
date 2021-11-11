import 'package:test/test.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'fixture/fixture_data.dart';

void main() {
  group('TransitionHandlerBuilder', () {
    group('run', () {
      test('should run handler on enter', () async {
        var b = StateTreeBuilder(initialState: state1);
        var handlerCalled = false;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
        });
        b.state(state2, (b) {
          b.onEnter((b) => b.run((ctx) => handlerCalled = true));
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(handlerCalled, isTrue);
      });

      test('should run handler on exit', () async {
        var b = StateTreeBuilder(initialState: state1);
        var handlerCalled = false;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
          b.onExit((b) => b.run((ctx) => handlerCalled = true));
        });
        b.state(state2, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(handlerCalled, isTrue);
      });
    });

    group('updateData', () {
      test('should update data', () async {
        var b = StateTreeBuilder.withDataRoot<StateData>(
          rootState,
          InitialData(() => StateData()),
          emptyDataState,
          InitialChild(state1),
        );
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
        });
        b.state(state2, (b) {
          b.onEnter((b) => b.updateData<StateData>((transCtx, data) => data..val = '1'));
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.dataValue<StateData>()!.val, equals('1'));
      });
    });

    group('post', () {
      test('should post message', () async {
        var b = StateTreeBuilder(initialState: state1);
        var msgToPost = Message2();
        dynamic postedMsg;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
        });
        b.state(state2, (b) {
          b.onEnter((b) => b.post(message: msgToPost));
          b.onMessage<Message2>(
              (b) => b.goTo(state3, action: b.act.run((msgCtx, msg) => postedMsg = msg)));
        });
        b.state(state3, emptyState);

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.key, equals(state3));
        expect(postedMsg, equals(msgToPost));
      });

      test('should post message to destination state when posted in onExit', () async {
        var b = StateTreeBuilder(initialState: state1);
        var msgToPost = Message();
        dynamic postedMsg;

        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2));
          b.onExit((b) => b.post(message: msgToPost));
        });
        b.state(state2, (b) {
          b.onMessageValue(msgToPost, (b) {
            b.action(b.act.run((msgCtx, msg) => postedMsg = msg));
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(currentState.key, equals(state2));
        expect(postedMsg, equals(msgToPost));
      });
    });

    group('when', () {
      test('should run true handler when condition is true', () async {
        var b = StateTreeBuilder(initialState: state1);
        var trueHandlerCalled = false;
        var otherwiseHandlerCalled = false;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2, payload: (_, __) => 1));
        });
        b.state(state2, (b) {
          b.onEnter((b) {
            b.when((transCtx) => 1 == transCtx.payload as int, (b) {
              b.run((ctx) => trueHandlerCalled = true);
            }).otherwise((b) {
              b.run((ctx) => otherwiseHandlerCalled = true);
            });
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(trueHandlerCalled, isTrue);
        expect(otherwiseHandlerCalled, isFalse);
      });

      test('should run true handler for first condition that is true', () async {
        var b = StateTreeBuilder(initialState: state1);
        var trueHandlerCalled = false;
        var trueHandler2Called = false;
        var otherwiseHandlerCalled = false;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2, payload: (_, __) => 1));
        });
        b.state(state2, (b) {
          b.onEnter((b) {
            b.when((transCtx) => 1 == transCtx.payload as int, (b) {
              b.run((ctx) => trueHandlerCalled = true);
            }).when((transCtx) => 1 == transCtx.payload as int, (b) {
              b.run((ctx) => trueHandler2Called = true);
            }).otherwise((b) {
              b.run((ctx) => otherwiseHandlerCalled = true);
            });
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(trueHandlerCalled, isTrue);
        expect(trueHandler2Called, isFalse);
        expect(otherwiseHandlerCalled, isFalse);
      });

      test('should run otherwise handler when condition is not true', () async {
        var b = StateTreeBuilder(initialState: state1);
        var trueHandlerCalled = false;
        var otherwiseHandlerCalled = false;
        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2, payload: (_, __) => 2));
        });
        b.state(state2, (b) {
          b.onEnter((b) {
            b.when((transCtx) => 1 == transCtx.payload! as int, (b) {
              b.run((ctx) => trueHandlerCalled = true);
            }).otherwise((b) {
              b.run((ctx) => otherwiseHandlerCalled = true);
            });
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(trueHandlerCalled, isFalse);
        expect(otherwiseHandlerCalled, isTrue);
      });
    });
  });

  group('TransitionHandlerBuilderWithData', () {
    group('when', () {
      test('should run true handler when condition is true', () async {
        var b = StateTreeBuilder(initialState: state1);
        var initDataVal = StateData()..val = '2';
        var trueHandlerCalled = false;
        var otherwiseHandlerCalled = false;
        StateData? handlerDataVal;

        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2, payload: (_, __) => 1));
        });
        b.dataState<StateData>(state2, InitialData(() => initDataVal), (b) {
          b.onEnter((b) {
            b.when((transCtx, data) => '2' == data.val, (b) {
              b.run((ctx, data) {
                handlerDataVal = data;
                trueHandlerCalled = true;
              });
            }).otherwise((b) {
              b.run((ctx, data) => otherwiseHandlerCalled = true);
            });
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(trueHandlerCalled, isTrue);
        expect(handlerDataVal, same(initDataVal));
        expect(otherwiseHandlerCalled, isFalse);
      });

      test('should run otherwise handler when condition is not true', () async {
        var b = StateTreeBuilder(initialState: state1);
        var initDataVal = StateData()..val = '2';
        var trueHandlerCalled = false;
        var otherwiseHandlerCalled = false;
        StateData? handlerDataVal;

        b.state(state1, (b) {
          b.onMessage<Message>((b) => b.goTo(state2, payload: (_, __) => 2));
        });
        b.dataState<StateData>(state2, InitialData(() => initDataVal), (b) {
          b.onEnter((b) {
            b.when((transCtx, data) => '1' == data.val, (b) {
              b.run((ctx, data) => trueHandlerCalled = true);
            }).otherwise((b) {
              b.run((ctx, data) {
                handlerDataVal = data;
                otherwiseHandlerCalled = true;
              });
            });
          });
        });

        var stateMachine = TreeStateMachine(b);
        var currentState = await stateMachine.start();
        await currentState.post(Message());
        expect(trueHandlerCalled, isFalse);
        expect(handlerDataVal, same(initDataVal));
        expect(otherwiseHandlerCalled, isTrue);
      });
    });
  });

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
