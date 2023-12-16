import 'dart:collection';

import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// Type of functions that can create a [TreeNode].
typedef TreeNodeBuilder = TreeNode Function(TreeBuildContext context);

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This interface is infrastructure, and is not intended to be called by application code.
class TreeBuildContext {
  TreeBuildContext._(this._parentNode, this._nodes);

  /// Constructs a [TreeBuildContext].
  factory TreeBuildContext() => TreeBuildContext._(null, {});

  /// The current parent node for nodes that will be built.
  final TreeNode? _parentNode;

  /// Map of nodes that have been built.
  final Map<StateKey, TreeNode> _nodes;

  /// Map of nodes that have been built by this context.
  Map<StateKey, TreeNodeInfo> get nodes => _nodes;

  /// Creates a root [TreeNode] that is fully populated with its descendant nodes, based on the
  /// description provided by [nodeBuildInfo]
  RootTreeNode buildRoot(RootNodeBuildInfo nodeBuildInfo) {
    assert(!_nodes.containsKey(nodeBuildInfo.key));
    var children = <TreeNode>[];
    var node = RootTreeNode(
      nodeBuildInfo.key,
      nodeBuildInfo.createState,
      getInitialChild: nodeBuildInfo.initialChild,
      children: UnmodifiableListView(children),
      dataCodec: nodeBuildInfo.dataCodec,
      filters: nodeBuildInfo.filters,
      metadata: nodeBuildInfo.metadata,
    );

    final childCtx = _childBuildContext(node);
    children.addAll(
        nodeBuildInfo.childBuilders.map((buildChild) => buildChild(childCtx)));
    _addNode(node);

    return node;
  }

  /// Creates an interior [TreeNode] that is fully populated with its descendant nodes, based on the
  /// description provided by [nodeBuildInfo]
  InteriorTreeNode buildInterior(InteriorNodeBuildInfo nodeBuildInfo) {
    assert(_parentNode != null);
    assert(_parentNode is CompositeTreeNode);
    assert(nodeBuildInfo.childBuilders.isNotEmpty);

    var children = <TreeNode>[];
    var node = InteriorTreeNode(
      nodeBuildInfo.key,
      nodeBuildInfo.createState,
      parent: _parentNode as CompositeTreeNode,
      getInitialChild: nodeBuildInfo.initialChild,
      children: UnmodifiableListView(children),
      dataCodec: nodeBuildInfo.dataCodec,
      filters: nodeBuildInfo.filters,
      metadata: nodeBuildInfo.metadata,
    );

    final childCtx = _childBuildContext(node);
    children.addAll(
        nodeBuildInfo.childBuilders.map((buildChild) => buildChild(childCtx)));
    _addNode(node);

    return node;
  }

  /// Creates a leaf [TreeNode], based on the description provided by [nodeBuildInfo]
  LeafTreeNode buildLeaf(LeafNodeBuildInfo nodeBuildInfo) {
    assert(_parentNode != null);
    assert(_parentNode is CompositeTreeNode);

    var node = LeafTreeNode(
      nodeBuildInfo.key,
      nodeBuildInfo.createState,
      parent: _parentNode as CompositeTreeNode,
      isFinalState: nodeBuildInfo.isFinalState,
      dataCodec: nodeBuildInfo.dataCodec,
      filters: nodeBuildInfo.filters,
      metadata: nodeBuildInfo.metadata,
    );

    _addNode(node);
    return node;
  }

  void _addNode(TreeNode node) {
    if (_nodes.containsKey(node.key)) {
      final msg =
          'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    _nodes[node.key] = node;
  }

  // Constructs a [TreeBuildContext] that adusts the current parent node, so child nodes can be
  /// built.
  TreeBuildContext _childBuildContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, _nodes);
}
