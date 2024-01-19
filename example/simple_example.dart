import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

//
// State keys
//
class States {
  static const enterText = StateKey('simple_enterText');
  static const showUppercase = DataStateKey<String>('simple_showUppercase');
  static const showLowercase = StateKey('simple_showLowercase');
  static const finished = DataStateKey<String>('simple_finished');
}

//
// Messages
//
enum Messages { finish }

class ToUppercase {
  ToUppercase(this.text);
  final String text;
}

class ToLowercase {
  ToLowercase(this.text);
  final String text;
}

//
// State tree
//
// A flat (non-hierarchial) state tree illustrating simple branching and passing data between
// states.
final simpleStateTree = StateTree(
  InitialChild(States.enterText),
  childStates: [
    State(
      States.enterText,
      onMessage: (ctx) => switch (ctx.message) {
        ToUppercase(text: var text) =>
          ctx.goTo(States.showUppercase, payload: text),
        _ => ctx.unhandled()
      },
    ),
    DataState(
      States.showUppercase,
      InitialData.run((ctx) => (ctx.payload as String).toUpperCase()),
      onMessage: (ctx) => ctx.message == Messages.finish
          ? ctx.goTo(States.finished,
              payload: ctx.data(States.showUppercase).value)
          : ctx.unhandled(),
    ),
  ],
  finalStates: [
    FinalDataState(
      States.finished,
      InitialData.run((ctx) => (ctx.payload as String)),
    ),
  ],
);

Future<void> main() async {
  var stateMachine = TreeStateMachine(simpleStateTree);
  var currentState = await stateMachine.start();
  await currentState.post(ToUppercase('hi'));
  await currentState.post(Messages.finish);
  var uppercase = currentState.dataValue(States.finished);
  assert(uppercase == 'HI');
  print(uppercase);
}
