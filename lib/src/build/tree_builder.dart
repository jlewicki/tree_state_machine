import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/build.dart';

/// Defines a method for constructing a [RootNodeBuildInfo] the describes how to build a state tree.
///
/// Libraries that provide high-level APIs for defining a state tree must implement this interface
/// in order to translate the state tree as represented by the API into a [RootNodeBuildInfo] that
/// can be used by [StateTreeBuilder] to construct a state tree.
abstract interface class StateTreeBuildProvider {
  /// Creates a [RootNodeBuildInfo] that can be used by [StateTreeBuilder] to build a state tree.
  RootNodeBuildInfo createRootNodeBuildInfo();
}

/// Provides a [build] method that constructs a state tree.
///
/// [StateTreeBuilder] is primary means to supply a state tree to a [TreeStateMachine]. The typical
/// usage is to use a high-level builder API to define a state tree. This API provides a
/// [StateTreeBuildProvider] implementation that can construct a [RootNodeBuildInfo] that reifies
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
class StateTreeBuilder {
  StateTreeBuilder(
    this.treeBuildInfoProvider, {
    this.label,
    this.logName,
  });

  /// Describes how the root node of the state tree should be constructed when [build] is called.
  ///
  /// Because this [RootNodeBuildInfo] also describes how its descendants should be built, it provides
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

  /// Builds a state tree, and returns the root node of the tree.
  RootTreeNode build(TreeBuildContext buildContext) {
    return _buildNode(
            buildContext, treeBuildInfoProvider.createRootNodeBuildInfo())
        as RootTreeNode;
  }

  TreeNode _buildNode(
    TreeBuildContext buildContext,
    TreeNodeBuildInfo nodeBuildInfo,
  ) {
    return switch (nodeBuildInfo) {
      RootNodeBuildInfo() => buildContext.buildRoot(nodeBuildInfo),
      InteriorNodeBuildInfo() => buildContext.buildInterior(nodeBuildInfo),
      LeafNodeBuildInfo() => buildContext.buildLeaf(nodeBuildInfo),
    };
  }
}
