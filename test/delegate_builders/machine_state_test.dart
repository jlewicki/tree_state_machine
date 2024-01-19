import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

class States {
  static const machineState = MachineStateKey('nestedMachine');
  static const state1 = DataStateKey<StateData>('state1');
  static const nestedState1 = StateKey('nestedState1');
  static const nestedState2 = DataStateKey<StateData>('nestedState2');
  static const nestedState3 = StateKey('nestedState3');
}

final nestedStateTree = StateTree(
  InitialChild(States.nestedState1),
  childStates: [
    State(
      States.nestedState1,
      onMessage: (ctx) => switch (ctx.message) {
        'state2' => ctx.goTo(States.nestedState2),
        'state3' => ctx.goTo(States.nestedState3),
        _ => ctx.unhandled(),
      },
    ),
    State(States.nestedState3),
  ],
  finalStates: [
    FinalDataState(
      States.nestedState2,
      InitialData(() => StateData()..val = '1'),
    ),
  ],
);

StateTree stateTree(
  InitialMachine initialMachine, {
  MachineDisposedHandler? onMachineDisposed,
  bool Function(Transition)? isMachineDone,
}) {
  return StateTree(
    InitialChild(States.machineState),
    childStates: [
      MachineState(
        States.machineState,
        initialMachine,
        onMachineDone: (msgCtx, nestedCurrentState) {
          return msgCtx.goTo(
            States.state1,
            payload: nestedCurrentState.dataValue(States.nestedState2),
          );
        },
        onMachineDisposed: onMachineDisposed,
        isMachineDone: isMachineDone,
      ),
      DataState(
          States.state1,
          InitialData.run(
            (ctx) => switch (ctx.payload) {
              StateData() => ctx.payload as StateData,
              _ => StateData()..val = '-1'
            },
          )),
    ],
  );
}

void main() {
  group('MachineState', () {
    test('should create nested machine from tree builder', () async {
      var tree = stateTree(
        InitialMachine.fromStateTree((_) => nestedStateTree),
      );
      var stateMachine = TreeStateMachine(tree);
      var currentState = await stateMachine.start();
      var toState1Future =
          stateMachine.transitions.firstWhere((t) => t.to == States.state1);
      currentState.post('state2');
      await toState1Future;

      expect(currentState.key, equals(States.state1));
      expect(currentState.dataValue(States.state1)!.val, equals('1'));
    });

    test('should create nested machine from state machine', () async {
      var nestedSm = TreeStateMachine(nestedStateTree);
      await nestedSm.start();

      var tree = stateTree(
        InitialMachine.fromMachine((_) => nestedSm),
      );

      var stateMachine = TreeStateMachine(tree);
      var currentState = await stateMachine.start();
      var toState1Future =
          stateMachine.transitions.firstWhere((t) => t.to == States.state1);
      currentState.post('state2');
      await toState1Future;

      expect(currentState.key, equals(States.state1));
      expect(currentState.dataValue(States.state1)!.val, equals('1'));
    });
  });

  test('should create a nested machine that can complete out of band',
      () async {
    var nestedSm = TreeStateMachine(nestedStateTree);
    await nestedSm.start();

    var tree = stateTree(
      InitialMachine.fromMachine((_) => nestedSm),
      onMachineDisposed: (ctx) => ctx.goTo(States.state1),
    );

    var stateMachine = TreeStateMachine(tree);
    var currentState = await stateMachine.start();

    var toState1Future = stateMachine.transitions
        .firstWhere((t) => t.to == States.state1, orElse: null);
    nestedSm.dispose();
    await toState1Future;

    expect(currentState.key, equals(States.state1));
  });

  test('should use isDone to determine completion', () async {
    var tree = stateTree(
      InitialMachine.fromStateTree((_) => nestedStateTree),
      isMachineDone: (transition) => transition.to == States.nestedState3,
    );

    var stateMachine = TreeStateMachine(tree);
    var currentState = await stateMachine.start();
    var toState1Future =
        stateMachine.transitions.firstWhere((t) => t.to == States.state1);
    currentState.post('state3');
    await toState1Future;

    expect(currentState.key, equals(States.state1));
  });
}

class StateData {
  String val = '0';
}
