import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

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

/// A flat (non-hierarchial) state tree illustrating simple branching and passing data between
/// states.
class SimpleStateTree {
  DeclarativeStateTreeBuilder treeBuilder() {
    var b = DeclarativeStateTreeBuilder(
        initialChild: States.enterText, logName: 'simple');

    b.state(States.enterText, (b) {
      b.onMessage<ToUppercase>((b) =>
          b.goTo(States.showUppercase, payload: (ctx) => ctx.message.text));
    });

    b.dataState<String>(
      States.showUppercase,
      InitialData.run((ctx) => (ctx.payload as String).toUpperCase()),
      (b) {
        b.onMessageValue(
          Messages.finish,
          (b) => b.goTo(States.finished, payload: (ctx) {
            return ctx.data;
          }),
        );
      },
    );

    b.finalDataState<String>(
      States.finished,
      InitialData.run((ctx) {
        return ctx.payloadOrThrow<String>();
      }),
      emptyFinalState,
    );

    return b;
  }
}

Future<void> main() async {
  var stateMachine = TreeStateMachine(SimpleStateTree().treeBuilder());
  var currentState = await stateMachine.start();
  await currentState.post(ToUppercase('hi'));
  await currentState.post(Messages.finish);
  var uppercase = currentState.dataValue<String>();
  assert(uppercase == 'HI');
  print(uppercase);
}
