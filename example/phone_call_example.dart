import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

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

enum Messages {
  placedOnHold,
  takenOffHold,
  leftMessage,
  callConnected,
  muteMicrophone,
  unmuteMicrophone,
  phoneHurledAgainstWall,
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
      b.onMessage<Dial>((b) => b.enterChannel(ringingChannel, (_, msg) => msg));
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
      b.onMessageValue(Messages.muteMicrophone, (b) => b.stay(action: b.act.run(onMute)));
      b.onMessageValue(Messages.unmuteMicrophone, (b) => b.stay(action: b.act.run(onUnmute)));
      b.onMessageValue(Messages.leftMessage, (b) => b.goTo(States.offHook));
      b.onMessageValue(Messages.placedOnHold, (b) => b.goTo(States.onHold));
    }, initialChild: InitialChild(States.talking))
    ..state(States.talking, emptyState, parent: States.connected)
    ..state(States.onHold, (b) {
      b.onMessageValue(Messages.takenOffHold, (b) => b.goTo(States.connected));
      b.onMessageValue(Messages.phoneHurledAgainstWall, (b) => b.goTo(States.phoneDestroyed));
    }, parent: States.connected)
    ..finalState(States.phoneDestroyed, emptyFinalState);
}

void onCallStarted(TransitionContext ctx) {
  print('Call started at ${DateTime.now()}.');
}

void onCallEnded(TransitionContext ctx) {
  print('Call ended at ${DateTime.now()}.');
}

Future<void> onDialed(TransitionContext ctx, Dial? payload) async {
  print('Call placed to ${payload!.callee}.');
  print('Connecting...');
  ctx.schedule(() => Messages.callConnected, duration: Duration(seconds: 1), periodic: false);
}

void onMute(MessageContext ctx, Object? msg) {
  print('Microphone muted.');
}

void onUnmute(MessageContext ctx, Object? msg) {
  print('Microphone unmuted.');
}

Future<void> main() async {
  var treeBuilder = phoneCallStateTree();
  var stateMachine = TreeStateMachine(treeBuilder);
  var currentState = await stateMachine.start();

  await currentState.sendMessage(Dial('Carolyn'));
  assert(currentState.key == States.ringing);
  await stateMachine.transitions.first;
  assert(currentState.isInState(States.connected));

  var sink = StringBuffer();
  treeBuilder.format(sink, DotFormatter());
  var dot = sink.toString();
  // var context = TreeBuildContext();
  // var node = treeBuilder.build(context);
}
