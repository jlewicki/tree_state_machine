import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import 'fixture/fixture_data.dart';

final Matcher throwsStateTreeDefinitionError =
    throwsA(isA<StateTreeDefinitionError>());
final stateNestedMachine = DataStateKey<NestedMachineData>('nestedMachine');

void main() {
  group('StateTreeBuilder', () {
    group('machineState', () {
      final nestedState1 = StateKey('nestedState1');
      final nestedState2 = DataStateKey<StateData>('nestedState2');
      final nestedState3 = StateKey('nestedState3');

      DeclarativeStateTreeBuilder createNestedBuilder() {
        var treeBuilder =
            DeclarativeStateTreeBuilder(initialChild: nestedState1);

        treeBuilder.state(nestedState1, (b) {
          b.onMessageValue('state2', (b) => b.goTo(nestedState2));
          b.onMessageValue('state3', (b) => b.goTo(nestedState3));
        });
        treeBuilder.finalDataState<StateData>(
          nestedState2,
          InitialData(() => StateData()..val = '1'),
          emptyFinalState,
        );
        treeBuilder.state(nestedState3, emptyState);

        return treeBuilder;
      }

      test('should create a machine state from tree builder', () async {
        var nestedSb = createNestedBuilder();

        StateData? finalNestedData;
        var sb = DeclarativeStateTreeBuilder(initialChild: stateNestedMachine);
        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromStateTree((_) => nestedSb),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) {
                      finalNestedData = ctx.context.dataValue(nestedState2);
                    },
                  ),
                ));
          },
        );
        sb.state(state2, emptyState);

        var stateMachine = TreeStateMachine(sb);
        var currentState = await stateMachine.start();
        var toState2Future =
            stateMachine.transitions.firstWhere((t) => t.to == state2);
        currentState.post('state2');
        await toState2Future;

        expect(currentState.key, equals(state2));
        expect(finalNestedData, isNotNull);
        expect(finalNestedData!.val, equals('1'));
      });

      test('should create a machine state from machine', () async {
        var nestedSb = createNestedBuilder();
        var nestedSm = TreeStateMachine(nestedSb);
        await nestedSm.start();

        var sb = DeclarativeStateTreeBuilder(initialChild: stateNestedMachine);
        StateData? finalNestedData;

        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) =>
                        finalNestedData = ctx.context.dataValue(nestedState2),
                  ),
                ));
          },
        );
        sb.state(state2, emptyState);

        var stateMachine = TreeStateMachine(sb);
        var currentState = await stateMachine.start();
        var toState2Future =
            stateMachine.transitions.firstWhere((t) => t.to == state2);
        currentState.post('state2');
        await toState2Future;

        expect(currentState.key, equals(state2));
        expect(finalNestedData, isNotNull);
        expect(finalNestedData!.val, equals('1'));
      });

      test('should create a nested machine that can complete out of band',
          () async {
        var nestedSb = createNestedBuilder();
        var nestedSm = TreeStateMachine(nestedSb);
        var nestedCurrentState = await nestedSm.start();

        var sb = DeclarativeStateTreeBuilder(initialChild: stateNestedMachine);
        StateData? finalNestedData;
        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) =>
                        finalNestedData = ctx.context.dataValue(nestedState2),
                  ),
                ));
          },
        );
        sb.state(state2, emptyState);

        var stateMachine = TreeStateMachine(sb);
        var currentState = await stateMachine.start();

        var toState2Future =
            stateMachine.transitions.firstWhere((t) => t.to == state2);
        await nestedCurrentState.post('state2');
        await toState2Future;

        expect(currentState.key, equals(state2));
        expect(finalNestedData, isNotNull);
        expect(finalNestedData!.val, equals('1'));
      });

      test('should create a nested machine that can dispose out of band',
          () async {
        var nestedSb = createNestedBuilder();
        var nestedSm = TreeStateMachine(nestedSb);
        await nestedSm.start();

        var sb = DeclarativeStateTreeBuilder(initialChild: stateNestedMachine);
        StateData? finalNestedData;
        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) =>
                        finalNestedData = ctx.context.dataValue(nestedState2),
                  ),
                ));
            b.onMachineDisposed((b) => b.goTo(state2));
          },
        );
        sb.state(state2, emptyState);

        var stateMachine = TreeStateMachine(sb);
        var currentState = await stateMachine.start();

        var toState2Future = stateMachine.transitions
            .firstWhere((t) => t.to == state2, orElse: null);
        nestedSm.dispose();
        await toState2Future;

        expect(currentState.key, equals(state2));
        expect(finalNestedData, isNull);
      });

      test('should ignore messages if forwardMessages is false', () async {
        var nestedSb = createNestedBuilder();
        var nestedSm = TreeStateMachine(nestedSb);
        await nestedSm.start();

        var sb = DeclarativeStateTreeBuilder(initialChild: stateNestedMachine);
        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromMachine((_) => nestedSm, forwardMessages: false),
          (b) {
            b.onMachineDone((b) => b.goTo(state2));
            b.onMachineDisposed((b) => b.goTo(state2));
          },
        );
        sb.state(state2, emptyState);

        var stateMachine = TreeStateMachine(sb);
        var currentState = await stateMachine.start();
        var msgResult = await currentState.post('state3');
        expect(msgResult, isA<HandledMessage>());
        expect((msgResult as HandledMessage).transition, isNull);
      });

      test('should use isDone to determine completion', () async {
        var nestedSb = createNestedBuilder();
        var nestedSm = TreeStateMachine(nestedSb);
        await nestedSm.start();

        var sb = DeclarativeStateTreeBuilder(initialChild: stateNestedMachine);
        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(state2));
          },
          isDone: (transition) => transition.to == nestedState3,
        );
        sb.state(state2, emptyState);

        var stateMachine = TreeStateMachine(sb);
        var currentState = await stateMachine.start();
        var toState2Future =
            stateMachine.transitions.firstWhere((t) => t.to == state2);
        currentState.post('state3');
        await toState2Future;

        expect(currentState.key, equals(state2));
      });

      test('should throw when not a leaf state', () async {
        var nestedSb = createNestedBuilder();

        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          stateNestedMachine,
          InitialMachine.fromStateTree((_) => nestedSb),
          (b) {
            b.onMachineDone((b) => b.goTo(state3));
          },
        );
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState);

        expect(
          () => TreeStateMachine(sb),
          throwsStateTreeDefinitionError,
        );
      });
    });
  });
}
