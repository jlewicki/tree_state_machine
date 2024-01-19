import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

//
// State keys
//
class States {
  static const s = StateKey('s');
  static const s1 = StateKey('s1');
  static const s11 = StateKey('s11');
  static const s2 = StateKey('s2');
  static const s21 = StateKey('s21');
}

//
// Messages
//
enum Messages { go }

//
// State Tree
//
// A state tree modeling the example at
// https://en.wikipedia.org/wiki/UML_state_machine#Transition_execution_sequence
//
// ┌───────────────────────────|s|─────────────────────────────┐
// │┌─────|s1|─────┐                    ┌────|s2|─────────────┐│
// ││ exit:b()     │                    │ entry:c()           ││
// ││┌───|s11|───┐ │                    │-*:d()->┌───|s21|───┐││
// │││ exit:a()  │ │--T1{guard:g(),     │        │ entry:e() │││
// │││           │ │      action:t()}-->│        │           │││
// ││└───────────┘ │                    │        └───────────┘││
// │└──────────────┘                    └─────────────────────┘│
// └───────────────────────────────────────────────────────────┘
final umlExampleStateTree = StateTree.root(
  States.s,
  InitialChild(States.s1),
  childStates: [
    State.composite(
      States.s1,
      InitialChild(States.s11),
      onMessage: (ctx) => g(ctx)
          ? ctx.goTo(
              States.s2,
              transitionAction: (_) => t(),
            )
          : ctx.unhandled(),
      onExit: (_) => b(),
      childStates: [
        State(
          States.s11,
          onExit: (_) => a(),
        ),
      ],
    ),
    State.composite(
      States.s2,
      InitialChild.run(d),
      onEnter: (_) => c(),
      childStates: [
        State(
          States.s21,
          onEnter: (_) => e(),
        ),
      ],
    ),
  ],
);

void a() {
  print('a');
}

void b() {
  print('b');
}

void c() {
  print('c');
}

StateKey d(TransitionContext ctx) {
  print('d');
  return States.s21;
}

void e() {
  print('e');
}

void t() {
  print('t');
}

bool g(MessageContext ctx) {
  return ctx.message == Messages.go;
}

Future<void> main() async {
  var stateMachine = TreeStateMachine(umlExampleStateTree);

  var currentState = await stateMachine.start();
  assert(currentState.key == States.s11);

  await currentState.post(Messages.go);
  assert(currentState.key == States.s21);
}
