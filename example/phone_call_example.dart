import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

//
// State keys
//
class States {
  static final offHook = StateKey('offHook');
  static final ringing = StateKey('ringing');
  static final connected = StateKey('connected');
  static final talking = StateKey('talking');
  static final onHold = StateKey('onHold');
  static final phoneDestroyed = StateKey('phoneDestroyed');
}

//
// Messages
//
class Dial {
  final String callee;
  Dial(this.callee);
}

class SetVolume {
  final int level;
  SetVolume(this.level);
}

enum Messages {
  placedOnHold,
  takenOffHold,
  leftMessage,
  callConnected,
  muteMicrophone,
  unmuteMicrophone,
  phoneHurledAgainstWall,
  hangUp,
}

//
// State tree
//
final phoneCallStateTree = StateTree(
  InitialChild(States.offHook),
  children: [
    State(
      States.offHook,
      onMessage: (ctx) => switch (ctx.message) {
        Dial() => ctx.goTo(States.ringing, payload: ctx.message),
        _ => ctx.unhandled()
      },
    ),
    State(
      States.ringing,
      onEnter: onDialed,
      onMessage: (ctx) => ctx.message == Messages.callConnected
          ? ctx.goTo(States.connected)
          : ctx.unhandled(),
    ),
    State.composite(
      States.connected,
      InitialChild(States.talking),
      onEnter: onCallStarted,
      onExit: onCallEnded,
      onMessage: (ctx) {
        if (ctx.message == Messages.muteMicrophone) {
          onMute(ctx);
          return ctx.stay();
        } else if (ctx.message == Messages.unmuteMicrophone) {
          onUnmute(ctx);
          return ctx.stay();
        } else if (ctx.message is SetVolume) {
          onSetVolume(ctx.message as SetVolume);
          return ctx.stay();
        } else if (ctx.message == Messages.leftMessage) {
          return ctx.goTo(States.offHook);
        } else if (ctx.message == Messages.placedOnHold) {
          return ctx.goTo(States.onHold);
        } else if (ctx.message == Messages.takenOffHold) {
          return ctx.goTo(States.connected);
        } else if (ctx.message == Messages.hangUp) {
          return ctx.goTo(States.offHook);
        }
        return ctx.unhandled();
      },
      children: [
        State(States.talking),
        State(
          States.onHold,
          onMessage: (ctx) => switch (ctx.message) {
            Messages.takenOffHold => ctx.goTo(States.connected),
            Messages.phoneHurledAgainstWall => ctx.goTo(States.phoneDestroyed),
            _ => ctx.unhandled(),
          },
        ),
      ],
    ),
    State(States.phoneDestroyed, isFinal: true),
  ],
);

void onCallStarted(TransitionContext ctx) {
  print('Call started at ${DateTime.now()}.');
}

void onCallEnded(TransitionContext ctx) {
  print('Call ended at ${DateTime.now()}.');
}

Future<void> onDialed(TransitionContext ctx) async {
  print('Call placed to ${ctx.payloadOrThrow<Dial>().callee}.');
  print('Connecting...');
  ctx.schedule(
    () => Messages.callConnected,
    duration: Duration(seconds: 1),
    periodic: false,
  );
}

void onMute(MessageContext ctx) {
  print('Microphone muted.');
}

void onUnmute(MessageContext ctx) {
  print('Microphone unmuted.');
}

void onSetVolume(SetVolume setVolume) {
  print('Volume set to ${setVolume.level}');
}

Future<void> main() async {
  var stateMachine = TreeStateMachine(phoneCallStateTree);
  var currentState = await stateMachine.start();

  await currentState.post(Dial('Carolyn'));
  assert(currentState.key == States.ringing);

  // Wait for call to be connected
  await stateMachine.transitions.first;
  assert(currentState.isInState(States.connected));
  assert(currentState.key == States.talking);

  await currentState.post(SetVolume(4));

  await currentState.post(Messages.placedOnHold);
  assert(currentState.isInState(States.onHold));

  await currentState.post(Messages.takenOffHold);
  assert(currentState.key == States.talking);

  await currentState.post(Messages.hangUp);
  assert(currentState.key == States.offHook);
}
