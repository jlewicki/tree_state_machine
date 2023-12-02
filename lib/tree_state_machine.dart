/// Provides support for executing hierarchical state machines.
library tree_state_machine;

export 'src/machine/extensions.dart';
export 'src/machine/tree_state.dart'
    hide
        TreeState,
        DelegatingTreeState,
        DataTreeState,
        DelegatingDataTreeState,
        NestedMachineState,
        GoToResult,
        InternalTransitionResult,
        SelfTransitionResult,
        StopResult,
        UnhandledResult,
        StateCreator;
export 'src/machine/initial_state_data.dart';
export 'src/machine/data_value.dart' hide ClosableDataValue, VoidDataValue;
export 'src/machine/tree_state_machine.dart'
    hide TestableTreeStateMachine, EncodableState, EncodableTree;
export 'src/machine/lifecycle.dart' show LifecycleState;
