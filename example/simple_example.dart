import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

//
// State keys
//
class SimpleStates {
  static const enterText = StateKey('simple_enterText');
  static const showUppercase = DataStateKey<String>('simple_showUppercase');
  static const showLowercase = StateKey('simple_showLowercase');
  static const finished = DataStateKey<String>('simple_finished');
}

typedef _S = SimpleStates;

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
  StateTreeBuilder treeBuilder() {
    var b = StateTreeBuilder(initialState: _S.enterText, logName: 'simple');

    b.state(_S.enterText, (b) {
      b.onMessage<ToUppercase>((b) => b.goTo(_S.showUppercase, payload: (ctx) => ctx.message.text));
    });

    b.dataState<String>(
      _S.showUppercase,
      InitialData.run((ctx) => (ctx.payload as String).toUpperCase()),
      (b) {
        b.onMessageValue(
          Messages.finish,
          (b) => b.goTo(SimpleStates.finished, payload: (ctx) {
            return ctx.data;
          }),
        );
      },
    );

    b.finalDataState<String>(
      _S.finished,
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
  var uppercase = currentState.dataValue<String>();
  await currentState.post(Messages.finish);
  uppercase = currentState.dataValue<String>();
  print(uppercase);
}
