import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import './../tree_builder.dart';
import './../state_builder.dart';
import './../handlers/messages/message_handler_descriptor.dart';
import './../handlers/transitions/transition_handler_descriptor.dart';

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
// Channels
//
final ringingChannel = Channel<Dial>(States.ringing);

//
// State tree
//
StateTreeBuilder phoneCallStateTree() {
  return StateTreeBuilder(initialState: States.offHook)
    ..state(States.offHook, (b) {
      b.onMessage<Dial>((b) => b.enterChannel(ringingChannel, (ctx) => ctx.message));
    })
    ..state(States.ringing, (b) {
      b.onEnterFromChannel<Dial>(ringingChannel, (b) => b.run(onDialed));
      b.onMessageValue(
        Messages.callConnected,
        (b) => b.goTo(States.connected),
        messageName: 'callConnected',
      );
    })
    ..state(States.connected, (b) {
      b.onEnter((b) => b.run(onCallStarted));
      b.onExit((b) => b.run(onCallEnded));
      b.onMessageValue(Messages.muteMicrophone, (b) => b.action(b.act.run(onMute)));
      b.onMessageValue(Messages.unmuteMicrophone, (b) => b.action(b.act.run(onUnmute)));
      b.onMessage<SetVolume>((b) => b.action(b.act.run(onSetVolume)));
      b.onMessageValue(Messages.leftMessage, (b) => b.goTo(States.offHook));
      b.onMessageValue(Messages.placedOnHold, (b) => b.goTo(States.onHold));
      b.onMessageValue(Messages.hangUp, (b) => b.goTo(States.offHook));
    }, initialChild: InitialChild(States.talking))
    ..state(States.talking, emptyState, parent: States.connected)
    ..state(States.onHold, (b) {
      b.onMessageValue(Messages.takenOffHold, (b) => b.goTo(States.connected));
      b.onMessageValue(Messages.phoneHurledAgainstWall, (b) => b.goTo(States.phoneDestroyed));
    }, parent: States.connected)
    ..finalState(States.phoneDestroyed, emptyFinalState);
}

void onCallStarted(TransitionHandlerContext ctx) {
  print('Call started at ${DateTime.now()}.');
}

void onCallEnded(TransitionHandlerContext ctx) {
  print('Call ended at ${DateTime.now()}.');
}

Future<void> onDialed(TransitionHandlerContext<void, Dial> ctx) async {
  print('Call placed to ${ctx.context.callee}.');
  print('Connecting...');
  ctx.transitionContext.schedule(
    () => Messages.callConnected,
    duration: Duration(seconds: 1),
    periodic: false,
  );
}

void onMute(MessageHandlerContext ctx) {
  print('Microphone muted.');
}

void onUnmute(MessageHandlerContext ctx) {
  print('Microphone unmuted.');
}

void onSetVolume(MessageHandlerContext<SetVolume, void, void> ctx) {
  print('Volume set to ${ctx.message.level}');
}

Future<void> main() async {
  var treeBuilder = phoneCallStateTree();
  var stateMachine = TreeStateMachine.fromNewBuilder(treeBuilder);
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
