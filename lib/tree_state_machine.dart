/// Provides support for executing hierarchical state machines.
library tree_state_machine;

export 'src/machine/extensions.dart';
export 'src/machine/tree_node.dart'
    show
        TreeNodeInfo,
        CompositeNodeInfo,
        RootNodeInfo,
        LeafNodeInfo,
        InteriorNodeInfo,
        TreeNodeInfoExtensions;
export 'src/machine/tree_state.dart'
    hide
        DataTreeState,
        DelegatingDataTreeState,
        DelegatingTreeState,
        GoToResult,
        InternalTransitionResult,
        NestedMachineState,
        SelfTransitionResult,
        StateCreator,
        StopResult,
        TreeState,
        UnhandledResult;
export 'src/machine/data_value.dart' hide ClosableDataValue, VoidDataValue;
export 'src/machine/tree_state_machine.dart'
    hide TestableTreeStateMachine, EncodableState, EncodableTree;
export 'src/machine/machine.dart' show StateMachineError;
export 'src/machine/lifecycle.dart' show LifecycleState;

// To publish:
// dart pub publish --dry-run
// git tag -a vX.X.X -m "Publish vX.X.X"
// git push origin vX.X.X
// dart pub publish
//
// If you mess up
// git tag -d vX.X.X
// git push --delete origin vX.X.X
