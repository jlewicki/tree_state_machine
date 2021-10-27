/// Provides support for executing hierarchical state machines.
library tree_state_machine;

export 'src/machine/extensions.dart';
export 'src/machine/tree_state.dart'
    hide
        TreeState,
        DataTreeState,
        GoToResult,
        InternalTransitionResult,
        SelfTransitionResult,
        StopResult,
        UnhandledResult;
export 'src/machine/data_value.dart' hide ClosableDataValue;
export 'src/machine/tree_state_machine.dart'
    hide TestableTreeStateMachine, EncodableState, EncodableTree;
