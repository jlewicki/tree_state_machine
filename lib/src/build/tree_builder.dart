import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'tree_build_context.dart';
import 'tree_node.dart';
import 'tree_node_info.dart';

/// Defines a method for constructing a [RootNodeInfo] the describes how to build a state tree.
///
/// Libraries that provide high-level APIs for defining a state tree must implement this interface
/// in order to translate the state tree as represented by the API into a [RootNodeInfo] that
/// can be used by [StateTreeBuilder] to construct a state tree.
abstract interface class StateTreeBuildProvider {
  /// Creates a [RootNodeInfo] that can be used by [StateTreeBuilder] to build a state tree.
  RootNodeInfo createRootNodeInfo();
}

/// An error that can be thrown if a [StateTreeBuildProvider] produces an invalid state tree
/// definition.
class StateTreeDefinitionError extends Error {
  final String message;
  StateTreeDefinitionError(this.message);
  @override
  String toString() => "Invalid definition: $message";
}

/// Provides a [build] method that constructs a state tree.
///
/// [StateTreeBuilder] is primary means to supply a state tree to a [TreeStateMachine]. The typical
/// usage is to use a high-level builder API to define a state tree. This API provides a
/// [StateTreeBuildProvider] implementation that can construct a [RootNodeInfo] that reifies
/// the definition of the tree. A [StateTreeBuilder] can then be constructed with this
/// implementation, which in turn can be used to construct a [TreeStateMachine].
///
/// ```dart
/// // Hypothetical class providing high-level API for defining a state tree
/// class MyTreeBuilder implements StateTreeBuildProvider {
///   // APIs for definining states...
///
///   RootNodeBuildInfo createRootNodeBuildInfo() {
///     // Create a RootNodeBuildInfo based on API calls
///     // to this builder....
///   }
/// }
///
/// var myBuilder = MyTreeBuilder();
/// // Call myBuilder methods to define a state tree....
///
/// // The state tree builder will call myBuilder.createRootNodeBuildInfo()
/// var treeBuilder = StateTreeBuilder(myBuilder);
///
/// // The state machine will call treeBuilder.build()
/// var stateMachine = TreeStateMachine(treeBuilder);
/// ```
/// If [createBuildContext] is provided, it will be called each time [build] is called, and the
/// resulting build context will be used during tree construction. This is typically not needed, but
/// may be useful in advanced scenarios requiring access to the state tree as it is built.
class StateTreeBuilder {
  /// Constructs a [StateTreeBuilder].
  StateTreeBuilder(
    this.treeBuildInfoProvider, {
    this.label,
    this.logName,
    this.createBuildContext,
  });

  /// Describes how the root node of the state tree should be constructed when [build] is called.
  ///
  /// Because this [RootNodeInfo] also describes how its descendants should be built, it provides
  /// a complete description of a state tree.
  final StateTreeBuildProvider treeBuildInfoProvider;

  /// An optional descriptive label for the state tree, for diagnostic purposes.
  final String? label;

  /// An optional name for the state tree that to be used as the suffix of the logger name used
  /// when logging messages.
  ///
  /// This can be used to correlate log messages with specific state trees when examining the log
  /// output.
  final String? logName;

  final TreeBuildContext Function()? createBuildContext;

  /// Builds a state tree, and returns the root node of the tree.
  ///
  /// A [buildContext] may optionally provided. This is typically not needed, but may be useful in
  /// advanced scenarios requiring access to the state tree as it is built.
  TreeNode build([TreeBuildContext? buildContext]) {
    var buildContext_ =
        buildContext ?? createBuildContext?.call() ?? TreeBuildContext();
    var rootNodeInfo = treeBuildInfoProvider.createRootNodeInfo();
    return buildContext_.buildTree(rootNodeInfo);
  }
}

/// A callable class that can select the initial child state of a parent state, when the parent state
/// is entered.
sealed class InitialChild {
  InitialChild._();

  /// Constructs an [InitialChild] indicating that the state identified by [initialChild] should be
  /// entered.
  factory InitialChild(StateKey initialChild) =>
      InitialChildByKey._(initialChild);

  /// Constructs an [InitialChild] that will run the [getInitialChild] function when the state is
  /// entered in order to determine the initial child,
  factory InitialChild.delegate(GetInitialChild getInitialChild) =>
      InitialChildByDelegate._(getInitialChild);

  /// Returns the key of the child state that should be entered.
  StateKey call(TransitionContext transCtx);
}

final class InitialChildByKey extends InitialChild {
  InitialChildByKey._(this.initialChild) : super._();
  final StateKey initialChild;

  @override
  StateKey call(TransitionContext transCtx) => initialChild;
}

final class InitialChildByDelegate extends InitialChild {
  InitialChildByDelegate._(this.initialChild) : super._();
  final GetInitialChild initialChild;

  @override
  StateKey call(TransitionContext transCtx) => initialChild(transCtx);
}
