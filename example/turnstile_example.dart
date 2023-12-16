import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';

enum Messages {
  insertCoin,
  push,
}

class States {
  static final locked = StateKey('locked');
  static final unlocked = StateKey('unlocked');
}

DeclarativeStateTreeBuilder turnstileStateTree() {
  return DeclarativeStateTreeBuilder(initialChild: States.locked)
    ..state(States.locked, (b) {
      b.onMessageValue(Messages.insertCoin, (b) => b.goTo(States.unlocked));
    })
    ..state(States.unlocked, (b) {
      b.onMessageValue(Messages.push, (b) => b.goTo(States.locked),
          messageName: 'push');
    });
}

Future<void> main() async {
  var declBuilder = turnstileStateTree();
  var stateMachine = TreeStateMachine(declBuilder);

  var currentState = await stateMachine.start();
  assert(currentState.key == States.locked);

  await currentState.post(Messages.insertCoin);
  assert(currentState.key == States.unlocked);

  await currentState.post(Messages.push);
  assert(currentState.key == States.locked);

  var sb = StringBuffer();
  declBuilder.format(sb, DotFormatter());
  print(sb.toString());
}
