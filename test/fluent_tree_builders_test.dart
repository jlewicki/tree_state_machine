import 'package:test/test.dart';
import 'package:tree_state_machine/src/builders/fluent_tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

void main() {
  var rootKey = StateKey.named('root');
  var state1 = StateKey.named('state1');
  var state2 = StateKey.named('state2');
  var state3 = StateKey.named('state3');

  group('StateTreeBuilder', () {
    group('finalState', () {
      test('should build final state', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2));
        builder.finalState(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(sm.isEnded, isTrue);
      });
    });
  });

  group('StateBuilder', () {
    group('onMessage', () {
      test('should handle message by type', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2));
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
      });

      test('should handle with first guard that returns true', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b
            .stay(when: (message, ctx) => false)
            .goTo(
              state2,
              when: (message, ctx) =>
                  Future.delayed(Duration(milliseconds: 25)).then((value) => true),
            )
            .goTo(
              state3,
              when: (message, ctx) => true,
            ));

        builder.state(state2);
        builder.state(state3);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
      });

      test('should handle message by value', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage((b) => b.goTo(state2), message: Message1());
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
      });

      test('should ignore unspecified messages by type', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2));
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Object());
        expect(sm.currentState.key, equals(state1));
      });

      test('should ignore unspecified messages by value', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage((b) => b.goTo(state2), message: Message1());
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Object());
        expect(sm.currentState.key, equals(state1));
      });

      test('should allow multiple calls for message', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder
            .state(state1)
            .onMessage<Message1>((b) => b.goTo(
                  state2,
                  when: (message, ctx) => false,
                ))
            .onMessage<Message1>((b) => b.goTo(
                  state3,
                  when: (message, ctx) => true,
                ));

        builder.state(state2);
        builder.state(state3);

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state3));
      });
    });

    group('onEnter', () {
      test('should enter', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2));

        var state2Entered = false;
        builder.state(state2).onEnter((b) => b.handle((ctx, _) => state2Entered = true));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(state2Entered, isTrue);
      });

      test('should enter with first guard that returns true', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2));

        var handler1Entered = false;
        var handler2Entered = false;
        var handler3Entered = false;
        builder.state(state2).onEnter((b) => b
            .handle(
              (ctx, _) => handler1Entered = true,
              when: (ctx, data) => false,
            )
            .handle(
              (ctx, _) => handler2Entered = true,
              when: (ctx, data) => true,
            )
            .handle(
              (ctx, _) => handler3Entered = true,
              when: (ctx, data) => true,
            ));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(handler1Entered, isFalse);
        expect(handler2Entered, isTrue);
        expect(handler3Entered, isFalse);
      });

      test('should enter from channel', () async {
        var message = 'Foo';
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var channel = EntryChannel<Payload>(state2);
        builder.state(state1).onMessage<Message2>(
            (b) => b.enterChannel<Payload>(channel, payload: (m, ctx) => Payload(m.payload)));

        var channelEntered = false;
        builder.state(state2).onEnter<Object, Payload>((b) =>
            b.handleWithPayload((ctx, p) => channelEntered = p.info == message, channel: channel));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message2(message));
        expect(sm.currentState.key, equals(state2));
        expect(channelEntered, isTrue);
      });

      test('should updateData', () async {
        var payload = 'foo';
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder
            .state(state1)
            .onMessage<Message1>((b) => b.goTo(state2, payload: (m, ctx) => payload));

        builder
            .dataState<StateData>(state2)
            .withDataProvider(() => OwnedDataProvider<StateData>(() => StateData()))
            .onEnter<StateData, String>(
                (b) => b.updateDataFromPayload((d, payload) => d.info = payload));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(sm.currentState.findData<StateData>().info, payload);
      });

      test('should replaceData', () async {
        var payload = 'foo';
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder
            .state(state1)
            .onMessage<Message1>((b) => b.goTo(state2, payload: (m, ctx) => payload));

        builder
            .dataState<StateData>(state2)
            .withDataProvider(() => OwnedDataProvider<StateData>(() => StateData()))
            .onEnter<StateData, String>(
                (b) => b.replaceDataFromPayload((d, payload) => StateData()..info = payload));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(sm.currentState.findData<StateData>().info, payload);
      });
    });

    group('onExit', () {
      test('should exit', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var state1Exited = false;
        builder
            .state(state1)
            .onMessage<Message1>((b) => b.goTo(state2))
            .onExit((b) => b.handle((ctx, _) => state1Exited = true));
        builder.state(state2);

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(state1Exited, isTrue);
      });

      test('should exit with first guard that returns true', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);

        var handler1Exited = false;
        var handler2Exited = false;
        var handler3Exited = false;
        builder
            .state(state1)
            .onMessage<Message1>(
              (b) => b.goTo(state2),
            )
            .onExit(
              (b) => b
                  .handle(
                (ctx, _) => handler1Exited = true,
                when: (ctx, data) => false,
              )
                  .handle(
                (ctx, _) async {
                  await Future.delayed(Duration(milliseconds: 25));
                  handler2Exited = true;
                },
                when: (ctx, data) => true,
              ).handle(
                (ctx, _) => handler3Exited = true,
                when: (ctx, data) => true,
              ),
            );

        builder.state(state2);

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(handler1Exited, isFalse);
        expect(handler2Exited, isTrue);
        expect(handler3Exited, isFalse);
      });

      test('should updateData', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var data1 = StateData();
        builder
            .dataState<StateData>(state1)
            .withDataProvider(() => OwnedDataProvider<StateData>(() => data1))
            .onMessage<Message1>((b) => b.goTo(state2))
            .onExit<StateData>((b) => b.updateData((d) => d..info = 'exited'));

        builder.state(state2).onMessage<Message1>((b) => b.goTo(state1));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
        expect(sm.currentState.findData<StateData>(), same(data1));
        expect(sm.currentState.findData<StateData>().info, 'exited');
      });

      test('should replaceData', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var data1 = StateData();
        var data2 = StateData();
        builder
            .dataState<StateData>(state1)
            .withDataProvider(() => OwnedDataProvider<StateData>(() => data1))
            .onMessage<Message1>((b) => b.goTo(state2))
            .onExit<StateData>((b) => b.replaceData((d) => data2));

        builder.state(state2).onMessage<Message1>((b) => b.goTo(state1));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
        expect(sm.currentState.findData<StateData>(), same(data2));
      });
    });
  });

  group('MessageHandlerBuilder', () {
    group('goTo', () {
      test('should go to target state', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2));
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
      });

      test('should go to target state with first guard that returns true', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(state2, when: (m, ctx) => true));
        builder.state(state2);
        builder.state(state3);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
      });

      test('should go to target state when guard returns future true', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(
              state2,
              when: (m, ctx) => Future.delayed(Duration(milliseconds: 50), () => true),
            ));
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
      });

      test('should not go to target state when guard returns future false ', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(
              state2,
              when: (m, ctx) => Future.delayed(Duration(milliseconds: 50), () => false),
            ));
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
      });

      test('should set payload', () async {
        var payload = Payload('hi');
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.goTo(
              state2,
              payload: (m, ctx) => Future.delayed(Duration(milliseconds: 25)).then((_) => payload),
            ));
        Payload entryPayload;
        builder.state(state2).onEnter<Payload, Object>(
              (b) => b.handle((ctx, _) => entryPayload = ctx.payload as Payload),
            );
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(entryPayload, same(payload));
      });

      test('should set transition action', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var actionCalled = false;
        builder.state(state1).onMessage<Message1>((b) => b.goTo(
              state2,
              transitionAction: (ctx) => actionCalled = true,
            ));
        builder.state(state2);
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state2));
        expect(actionCalled, isTrue);
      });

      test('should set reenterTarget', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var entered = false;
        builder
            .state(state1)
            .onEnter((b) => b.handle((ctx, _) => entered = true))
            .onMessage<Message1>((b) => b.goTo(
                  state1,
                  reenterTarget: true,
                ));
        var sm = TreeStateMachine(builder);
        await sm.start();
        entered = false;
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
        expect(entered, isTrue);
      });
    });

    group('stay', () {
      test('should stay in current state', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.stay());
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
      });

      test('should stay in current state when guard returns true', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.stay(when: (m, ctx) => true));
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
      });

      test('should be unhandled when guard returns false', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message1>((b) => b.stay(when: (m, ctx) => false));
        var sm = TreeStateMachine(builder);
        await sm.start();
        var result = await sm.currentState.sendMessage(Message1());
        expect(result, isA<UnhandledMessage>());
      });

      test('should set stayAction', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var actionWasCalled = false;
        builder.state(state1).onMessage<Message1>((b) => b.stay(
              before: (m, ctx) => actionWasCalled = true,
            ));
        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
        expect(actionWasCalled, isTrue);
      });
    });

    group('enterChannel', () {
      test('should set payload and enter channel', () async {
        var entryInfo = 'foo';
        var state2Entry = EntryChannel<Payload>(state2);
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message2>(
            (b) => b.enterChannel<Payload>(state2Entry, payload: (m, ctx) => Payload(m.payload)));

        var channelEntered = false;
        builder.state(state2).onEnter<Object, Payload>((b) => b.handleWithPayload(
              (ctx, p) => channelEntered = p.info == entryInfo,
              channel: state2Entry,
            ));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message2(entryInfo));
        expect(sm.currentState.key, equals(state2));
        expect(channelEntered, isTrue);
      });

      test('should enter channel when guard is true', () async {
        var entryInfo = 'foo';
        var state2Entry = EntryChannel<Payload>(state2);
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message2>((b) => b.enterChannel<Payload>(
              state2Entry,
              payload: (m, ctx) => Payload(m.payload),
              when: (m, ctx) => true,
            ));

        var channelEntered = false;
        builder.state(state2).onEnter<Object, Payload>((b) => b.handleWithPayload(
              (ctx, p) => channelEntered = p.info == entryInfo,
              channel: state2Entry,
            ));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message2(entryInfo));
        expect(sm.currentState.key, equals(state2));
        expect(channelEntered, isTrue);
      });

      test('should set transition action', () async {
        var entryInfo = 'foo';
        var state2Entry = EntryChannel<Payload>(state2);
        var builder = StateTreeBuilder.rooted(rootKey, state1);

        var actionCalled = false;
        builder.state(state1).onMessage<Message2>((b) => b.enterChannel<Payload>(
              state2Entry,
              payload: (m, ctx) => Payload(m.payload),
              transitionAction: (ctx) => actionCalled = true,
            ));

        builder.state(state2);

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message2(entryInfo));
        expect(sm.currentState.key, equals(state2));
        expect(actionCalled, isTrue);
      });

      test('should set reenterTarget', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var entered = false;
        builder
            .state(state1)
            .onEnter((b) => b.handle((ctx, _) => entered = true))
            .onMessage<Message1>((b) => b.goTo(
                  state1,
                  reenterTarget: true,
                ));
        var sm = TreeStateMachine(builder);
        await sm.start();
        entered = false;
        await sm.currentState.sendMessage(Message1());
        expect(sm.currentState.key, equals(state1));
        expect(entered, isTrue);
      });

      test('should set reenterTarget', () async {
        var entryInfo = 'foo';
        var state1Entry = EntryChannel<Payload>(state1);
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var state1Entered = false;
        builder
            .state(state1)
            .onEnter((b) => b.handle((ctx, _) => state1Entered = true))
            .onMessage<Message2>((b) => b.enterChannel<Payload>(
                  state1Entry,
                  payload: (m, ctx) => Payload(m.payload),
                  reenterTarget: true,
                ));

        var sm = TreeStateMachine(builder);
        await sm.start();
        state1Entered = false;
        await sm.currentState.sendMessage(Message2(entryInfo));
        expect(sm.currentState.key, equals(state1));
        expect(state1Entered, isTrue);
      });
    });
  });

  group('TransitionHandlerBuilder', () {
    group('handleWithPayload', () {
      test('should handle with payload', () async {
        var message = 'Foo';
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder
            .state(state1)
            .onMessage<Message2>((b) => b.goTo(state2, payload: (m, ctx) => Payload(m.payload)));

        var handled = false;
        builder.state(state2).onEnter<Object, Payload>((b) => b.handleWithPayload((ctx, p) async {
              await Future.delayed(Duration(milliseconds: 25));
              handled = p.info == message;
            }));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message2(message));
        expect(sm.currentState.key, equals(state2));
        expect(handled, isTrue);
      });

      test('should read value from channel if provided', () async {
        var message = 'Foo';
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var channel = EntryChannel<Payload>(state2);
        builder.state(state1).onMessage<Message2>(
            (b) => b.enterChannel<Payload>(channel, payload: (m, ctx) => Payload(m.payload)));

        var channelEntered = false;
        builder.state(state2).onEnter<Object, Payload>((b) =>
            b.handleWithPayload((ctx, p) => channelEntered = p.info == message, channel: channel));

        var sm = TreeStateMachine(builder);
        await sm.start();
        await sm.currentState.sendMessage(Message2(message));
        expect(sm.currentState.key, equals(state2));
        expect(channelEntered, isTrue);
      });

      test('should throw from handler if wrong payload type is provided', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder
            .state(state1)
            .onMessage<Message2>((b) => b.goTo(state2, payload: (m, ctx) => Object()));

        var handled = false;
        builder.state(state2).onEnter<Object, Payload>((b) => b.handleWithPayload((ctx, p) async {
              await Future.delayed(Duration(milliseconds: 25));
              handled = true;
            }));

        var sm = TreeStateMachine(builder);
        await sm.start();
        var result = await sm.currentState.sendMessage(Message2('Foo'));
        expect(sm.currentState.key, equals(state1));
        expect(handled, isFalse);
        expect(result, isA<FailedMessage>());
      });

      test('should throw from handler if no payload is provided', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        builder.state(state1).onMessage<Message2>((b) => b.goTo(state2));

        var handled = false;
        builder.state(state2).onEnter<Object, Payload>((b) => b.handleWithPayload((ctx, p) async {
              await Future.delayed(Duration(milliseconds: 25));
              handled = true;
            }));

        var sm = TreeStateMachine(builder);
        await sm.start();
        var result = await sm.currentState.sendMessage(Message2('Foo'));
        expect(sm.currentState.key, equals(state1));
        expect(handled, isFalse);
        expect(result, isA<FailedMessage>());
      });

      test('should throw from handler if no payload is provided for channel', () async {
        var message = 'Foo';
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var channel = EntryChannel<Payload>(state2);
        builder.state(state1).onMessage<Message2>(
            (b) => b.enterChannel<Payload>(channel, payload: (m, ctx) => null));

        var channelEntered = false;
        builder.state(state2).onEnter<Object, Payload>((b) =>
            b.handleWithPayload((ctx, p) => channelEntered = p.info == message, channel: channel));

        var sm = TreeStateMachine(builder);
        await sm.start();
        var result = await sm.currentState.sendMessage(Message2(message));
        expect(sm.currentState.key, equals(state1));
        expect(channelEntered, isFalse);
        expect(result, isA<FailedMessage>());
      });

      test('should throw if channel state does not match entry state', () async {
        var builder = StateTreeBuilder.rooted(rootKey, state1);
        var channel = EntryChannel<Payload>(state3);
        expect(
            () => builder.state(state2).onEnter<Object, Payload>(
                (b) => b.handleWithPayload((ctx, p) {}, channel: channel)),
            throwsArgumentError);
      });
    });
  });
}

class Message1 {
  @override
  bool operator ==(Object other) {
    return other.runtimeType == runtimeType;
  }

  @override
  int get hashCode {
    var hash = 7;
    hash = 31 * hash + runtimeType.hashCode;
    return hash;
  }
}

class Message2 {
  final String payload;
  Message2(this.payload);
}

class Payload {
  final String info;
  Payload(this.info);
}

class StateData {
  String info;
  StateData([this.info]);
}
