/// A library for creating and using tree (hierarchical) state machines.
///
///
library tree_state_machine.tree_state_machine;

export 'src/data_provider.dart';
export 'src/tree_builders.dart';
export 'src/tree_state.dart'
    hide GoToResult, InternalTransitionResult, SelfTransitionResult, UnhandledResult;
export 'src/tree_state_machine.dart' hide EncodableState, EncodableTree, CurrentLeafObservableData;
