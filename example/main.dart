import 'package:logging/logging.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// A simple stoplight that transitions between green/yellow/red when it is
//in the running state.
//
// See other examples at
// https://github.com/jlewicki/tree_state_machine/tree/master/example

class States {
  static const running = StateKey('running');
  static const green = StateKey('green');
  static const yellow = StateKey('yellow');
  static const red = StateKey('red');
  static const stopped = StateKey('stopped');
}

enum Messages { timeout, stop, start }

final greenTimeout = Duration(seconds: 5);
final yellowTimeout = Duration(seconds: 2);
final redTimeout = Duration(seconds: 5);

final stoplightStateTree = StateTree(
  InitialChild(States.stopped),
  childStates: [
    State.composite(
      States.running,
      InitialChild(States.green),
      onMessage: (ctx) => ctx.message == Messages.stop
          ? ctx.goTo(States.stopped)
          : ctx.unhandled(),
      childStates: [
        State(
          States.green,
          onEnter: (ctx) =>
              ctx.schedule(() => Messages.timeout, duration: greenTimeout),
          onMessage: (ctx) => ctx.message == Messages.timeout
              ? ctx.goTo(States.yellow)
              : ctx.unhandled(),
        ),
        State(
          States.yellow,
          onEnter: (ctx) => ctx.schedule(
            () => Messages.timeout,
            duration: yellowTimeout,
          ),
          onMessage: (ctx) => ctx.message == Messages.timeout
              ? ctx.goTo(States.red)
              : ctx.unhandled(),
        ),
        State(
          States.red,
          onEnter: (ctx) => ctx.schedule(
            () => Messages.timeout,
            duration: redTimeout,
          ),
          onMessage: (ctx) => ctx.message == Messages.timeout
              ? ctx.goTo(States.green)
              : ctx.unhandled(),
        )
      ],
    ),
    State(
      States.stopped,
      onMessage: (ctx) {
        return ctx.message == Messages.start
            ? ctx.goTo(States.running)
            : ctx.unhandled();
      },
    ),
  ],
);

Future<void> main() async {
  hierarchicalLoggingEnabled = true;

  var stateMachine = TreeStateMachine(
    stoplightStateTree,
    enableDeveloperLogging: true,
    logName: 'Stoplight',
  );
  var currentState = await stateMachine.start();

  await currentState.post(Messages.start);
  assert(currentState.key == States.green);

  await Future<void>.delayed(Duration(seconds: 15));

  await currentState.post(Messages.stop);
  assert(currentState.key == States.stopped);
}
