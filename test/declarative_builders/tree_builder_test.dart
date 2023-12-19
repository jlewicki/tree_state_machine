import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import '../utility.dart';
import 'fixture/fixture_data.dart';

final Matcher throwsStateTreeDefinitionError =
    throwsA(isA<StateTreeDefinitionError>());

void main() {
  group('StateTreeBuilder', () {
    final rootState = StateKey('r');
    final state1 = StateKey('s1');
    final state2 = StateKey('s2');
    final state3 = StateKey('s3');

    group('factory', () {
      test('should create implicit root state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState);
        var rootNode = sb();
        expect(DeclarativeStateTreeBuilder.defaultRootKey, rootNode.key);
        expect(1, rootNode.children.length);
        expect(state1, rootNode.children.first.key);
        expect(DeclarativeStateTreeBuilder.defaultRootKey,
            rootNode.children.first.parent()!.key);
        expect(sb.rootKey, DeclarativeStateTreeBuilder.defaultRootKey);
      });
    });

    group('factory.withRoot', () {
      test('should create explicit root state', () {
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.state(state1, emptyState);
        var rootNode = sb();
        expect(rootState, rootNode.key);
        expect(1, rootNode.children.length);
        expect(state1, rootNode.children.first.key);
        expect(rootState, rootNode.children.first.parent()!.key);
        expect(sb.rootKey, rootState);
      });
    });

    group('factory.withDataRoot', () {
      final rootState = DataStateKey<int>('root');
      test('should create explicit root state', () {
        var sb = DeclarativeStateTreeBuilder.withDataRoot<int>(
          rootState,
          InitialData(() => 1),
          emptyState,
          InitialChild(state1),
        );
        sb.state(state1, emptyState);
        var rootNode = sb();
        expect(rootState, rootNode.key);
        expect(1, rootNode.children.length);
        expect(state1, rootNode.children.first.key);
        expect(rootState, rootNode.children.first.parent()!.key);
        expect(sb.rootKey, rootState);
      });
    });

    group('state', () {
      test('should create a leaf state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: null);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isLeaf, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.isEmpty, isTrue);
      });

      test('should create a leaf state (rooted)', () {
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.state(state1, emptyState, initialChild: null);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isLeaf, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.isEmpty, isTrue);
      });

      test('should create an interior state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState, parent: state1);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isInterior, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.length, 1);
        expect(state1Node.children.first.key, state2);
      });

      test('should create an interior state (rooted)', () {
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState, parent: state1);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isInterior, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.length, 1);
        expect(state1Node.children.first.key, state2);
      });

      test('should throw if state is defined more than once', () {
        var state1 = StateKey('s1');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: null);
        expect(() => sb.state(state1, emptyState, initialChild: null),
            throwsStateTreeDefinitionError);
      });
    });

    group('dataState', () {
      test('should create a leaf state', () {
        final state1 = DataStateKey<int>('state1');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.dataState<int>(state1, InitialData(() => 1), emptyState,
            initialChild: null);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isLeaf, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.isEmpty, isTrue);
      });

      test('should create a leaf state (rooted)', () {
        final state1 = DataStateKey<int>('state1');
        var sb = DeclarativeStateTreeBuilder.withRoot(
            rootState, InitialChild(state1), emptyState);
        sb.dataState<int>(state1, InitialData(() => 1), emptyState,
            initialChild: null);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isLeaf, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.isEmpty, isTrue);
      });

      test('should create an interior state', () {
        final state1 = DataStateKey<String>('state1');
        final state2 = DataStateKey<String>('state2');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.dataState<String>(state1, InitialData(() => ''), emptyState,
            initialChild: InitialChild(state2));
        sb.dataState<String>(state2, InitialData(() => ''), emptyState,
            parent: state1);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isInterior, isTrue);
        expect(state1Node.isFinalLeaf, isFalse);
        expect(state1Node.children.length, 1);
        expect(state1Node.children.first.key, state2);
      });

      test('should throw if state is defined more than once', () {
        final state1 = DataStateKey<int>('state1');
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.dataState<int>(state1, InitialData(() => 1), emptyState,
            initialChild: null);
        expect(
          () => sb.dataState<int>(state1, InitialData(() => 1), emptyState,
              initialChild: null),
          throwsStateTreeDefinitionError,
        );
      });
    });

    group('finalState', () {
      test('should create a final leaf state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalState(state1, emptyFinalState);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isLeaf, isTrue);
        expect(state1Node.isFinalLeaf, isTrue);
        expect(state1Node.children.isEmpty, isTrue);
      });

      test('should throw if state is defined more than once', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalState(state1, emptyFinalState);
        expect(
          () => sb.finalState(state1, emptyFinalState),
          throwsStateTreeDefinitionError,
        );
      });
    });

    group('finalDataState', () {
      final state1 = DataStateKey<int>('state1');
      test('should create a final data leaf state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalDataState<int>(state1, InitialData(() => 1), emptyFinalState);
        var rootNode = sb();
        var state1Node = rootNode.children.first;
        expect(state1, state1Node.key);
        expect(state1Node.isLeaf, isTrue);
        expect(state1Node.isFinalLeaf, isTrue);
        expect(state1Node.children.isEmpty, isTrue);
      });

      test('should throw if state is defined more than once', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalDataState<int>(state1, InitialData(() => 1), emptyFinalState);
        expect(
          () => sb.finalDataState<int>(
              state1, InitialData(() => 1), emptyFinalState),
          throwsStateTreeDefinitionError,
        );
      });
    });

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
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          state1,
          InitialMachine.fromTree((_) => nestedSb.toTreeBuilder()),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) {
                      finalNestedData = ctx.context.dataValue<StateData>();
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

        StateData? finalNestedData;
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          state1,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) =>
                        finalNestedData = ctx.context.dataValue<StateData>(),
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

        StateData? finalNestedData;
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          state1,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) =>
                        finalNestedData = ctx.context.dataValue<StateData>(),
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

        StateData? finalNestedData;
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          state1,
          InitialMachine.fromMachine((_) => nestedSm),
          (b) {
            b.onMachineDone((b) => b.goTo(
                  state2,
                  action: b.act.run(
                    (ctx) =>
                        finalNestedData = ctx.context.dataValue<StateData>(),
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

        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          state1,
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

        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.machineState(
          state1,
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
          state1,
          InitialMachine.fromTree((_) => nestedSb.toTreeBuilder()),
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

    group('build', () {
      test('should throw if a parent state is missing initial child', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState);
        sb.state(state2, emptyState, parent: state1);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child is not defined', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child has no parent', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child has wrong parent', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState, parent: state4);
        sb.state(state4, emptyState, initialChild: InitialChild(state3));
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial child of implicit root has a parent', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state2);
        sb.state(state1, emptyState, initialChild: InitialChild(state3));
        sb.state(state2, emptyState, parent: state1);
        sb.state(state3, emptyState, parent: state4);
        sb.state(state4, emptyState, initialChild: InitialChild(state3));
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if there is a transition to an unknown state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, (b) {
          b.onMessage<String>((b) => b.goTo(state3));
        });
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if parent state is referenced but not defined', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState, parent: state3);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if initial state is referenced but not defined', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state3);
        sb.state(state1, emptyState);
        sb.state(state2, emptyState);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if circular parent-child references', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.state(state1, emptyState, initialChild: InitialChild(state2));
        sb.state(state2, emptyState,
            parent: state1, initialChild: InitialChild(state3));
        sb.state(state3, emptyState, parent: state1);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });

      test('should throw if a parent state is a final state', () {
        var sb = DeclarativeStateTreeBuilder(initialChild: state1);
        sb.finalState(state1, emptyFinalState);
        sb.state(state2, emptyState, parent: state1);
        expect(() => sb(), throwsStateTreeDefinitionError);
      });
    });
  });
}
