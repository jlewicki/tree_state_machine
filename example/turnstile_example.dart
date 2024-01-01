import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

//
// State keys
//
class States {
  static const locked = StateKey('locked');
  static const unlocked = StateKey('unlocked');
}

//
// Messages
//
enum Messages {
  insertCoin,
  push,
}

//
// State tree
//
// A flat (non-hierarchial) state tree illustrating transitioning between states.
final turnstileStateTree = StateTree(
  InitialChild(States.locked),
  childStates: [
    State(
      States.locked,
      onMessage: (ctx) => ctx.message == Messages.insertCoin
          ? ctx.goTo(States.unlocked)
          : ctx.unhandled(),
    ),
    State(
      States.unlocked,
      onMessage: (ctx) => ctx.message == Messages.push
          ? ctx.goTo(States.locked)
          : ctx.unhandled(),
    ),
  ],
);

Future<void> main() async {
  var stateMachine = TreeStateMachine(turnstileStateTree);

  var currentState = await stateMachine.start();
  assert(currentState.key == States.locked);

  await currentState.post(Messages.insertCoin);
  assert(currentState.key == States.unlocked);

  await currentState.post(Messages.push);
  assert(currentState.key == States.locked);
}
