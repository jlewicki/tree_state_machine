import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/tree_build.dart';

// /// Provides methods to build a state tree for use by a `TreeStateMachine`.
// abstract class StateTreeBuilder {
//   /// Optional descriptive label for this
//   String? get label;
//   String? get logName;

//   /// Describes how the root node of the state tree should be built.
//   ///
//   /// Because [RootNodeBuildInfo] contains [TreeNodeBuildInfo]s for all of its descendant nodes,
//   /// it is a description of a complete state tree.
//   ///
//   /// It is intended that subclasses will provide various high-level APIs for defining the
//   /// [TreeNodeBuildInfo] values that comprise a state tree, and compose them into the
//   /// [RootNodeBuildInfo]
//   RootNodeBuildInfo get rootBuildInfo;

//   /// Builds a state tree, and returns the [RootTreeNode] of the tree.
//   ///
//   /// The [buildContext] should be used o
//   RootTreeNode build(TreeBuildContext buildContext) {
//     return _buildNode(buildContext, rootBuildInfo) as RootTreeNode;
//   }

//   TreeNode _buildNode(
//     TreeBuildContext buildContext,
//     TreeNodeBuildInfo nodeBuildInfo,
//   ) {
//     return switch (nodeBuildInfo) {
//       RootNodeBuildInfo() => buildContext.buildRoot(nodeBuildInfo),
//       InteriorNodeBuildInfo() => buildContext.buildInterior(nodeBuildInfo),
//       LeafNodeBuildInfo() => buildContext.buildLeaf(nodeBuildInfo),
//     };
//   }
// }

abstract interface class StateTreeBuildProvider {
  RootNodeBuildInfo createRootNodeBuildInfo();
}

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
