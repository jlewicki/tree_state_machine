import 'dart:collection';

import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// Type of functions that can create a [TreeNode].
typedef TreeNodeBuilder = TreeNode Function(TreeBuildContext context);

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This interface is infrastructure, and is generally not used by application code.
class TreeBuildContext {
  TreeBuildContext._(this._parentNode, this._nodes, this.extendNodes);

  /// Constructs a [TreeBuildContext].
  factory TreeBuildContext({
    void Function(NodeBuildInfoBuilder)? extendNodes,
  }) =>
      TreeBuildContext._(null, {}, extendNodes);

  /// The current parent node for nodes that will be built.
  final TreeNode? _parentNode;

  /// Map of nodes that have been built.
  final Map<StateKey, TreeNode> _nodes;

  /// Map of nodes that have been built by this context.
  Map<StateKey, TreeNodeInfo> get nodes => _nodes;

  /// If provided, this function is called each time this context builds a tree node. The function
  /// is provided the [NodeBuildInfoBuilder] that can be used to augment the existing
  /// [TreeNodeBuildInfo] before it is used to construct a node.
  ///
  /// This is a low-level feature inteded to support general purpose extensions, and will not
  /// typically be used.
  void Function(NodeBuildInfoBuilder)? extendNodes;

  /// Creates a root [TreeNode] that is fully populated with its descendant nodes, based on the
  /// description provided by [nodeBuildInfo]
  RootTreeNode buildRoot(RootNodeBuildInfo nodeBuildInfo) {
    assert(!_nodes.containsKey(nodeBuildInfo.key));

    nodeBuildInfo = _transformRoot(nodeBuildInfo);

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

    nodeBuildInfo = _transformInterior(nodeBuildInfo);

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

    nodeBuildInfo = _transformLeaf(nodeBuildInfo);

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

  RootNodeBuildInfo _transformRoot(RootNodeBuildInfo node) {
    var transformBuilder = _applyTransform(node);
    return transformBuilder != null
        ? RootNodeBuildInfo(
            node.key,
            node.createState,
            childBuilders: node.childBuilders,
            initialChild: node.initialChild,
            dataCodec: node.dataCodec,
            filters: transformBuilder._filters,
            metadata: transformBuilder._metadata,
          )
        : node;
  }

  InteriorNodeBuildInfo _transformInterior(InteriorNodeBuildInfo node) {
    var transformBuilder = _applyTransform(node);
    return transformBuilder != null
        ? InteriorNodeBuildInfo(
            node.key,
            node.createState,
            parent: node.parent,
            childBuilders: node.childBuilders,
            initialChild: node.initialChild,
            dataCodec: node.dataCodec,
            filters: transformBuilder._filters,
            metadata: transformBuilder._metadata,
          )
        : node;
  }

  LeafNodeBuildInfo _transformLeaf(LeafNodeBuildInfo node) {
    var transformBuilder = _applyTransform(node);
    return transformBuilder != null
        ? LeafNodeBuildInfo(
            node.key,
            node.createState,
            parent: node.parent,
            isFinalState: node.isFinalState,
            dataCodec: node.dataCodec,
            filters: transformBuilder._filters,
            metadata: transformBuilder._metadata,
          )
        : node;
  }

  NodeBuildInfoBuilder? _applyTransform(TreeNodeBuildInfo nodeBuildInfo) {
    if (extendNodes == null) {
      return null;
    }

    var transformBuilder = NodeBuildInfoBuilder(
      nodeBuildInfo.key,
      Map.from(nodeBuildInfo.metadata),
      List.from(nodeBuildInfo.filters),
    );

    extendNodes!(transformBuilder);

    return transformBuilder;
  }

  // Constructs a [TreeBuildContext] that adusts the current parent node, so child nodes can be
  /// built.
  TreeBuildContext _childBuildContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, _nodes, extendNodes);
}

/// Provides methods for adding additional information to a [TreeNodeBuildInfo], before it is used
/// to construct a tree node.
///
/// ```dart
///  StateTreeBuildProvider treeProvider = defineStateTree();
///
///  var builder = StateTreeBuilder(
///    treeProvider,
///    createContext: () => TreeBuildContext(
///      extendNodes: (NodeBuildInfoBuilder b) {
///        b.metadata({"nodeKey": b.nodeKey})
///         .filter(filter2);
///      }
///    ),
///  );
///
///  var stateMachine = TreeStateMachine.withBuilder(builder);
/// ```
class NodeBuildInfoBuilder {
  /// Constructs a [NodeBuildInfoBuilder].
  NodeBuildInfoBuilder(this.nodeKey, this._metadata, this._filters);

  /// Identifies the [TreeNodeBuildInfo] to which this builder applies.
  final StateKey nodeKey;

  final List<TreeStateFilter> _filters;
  final Map<String, Object> _metadata;

  /// Adds all entries in [metadata] to [TreeNodeBuildInfo.metadata].
  ///
  /// Throws [StateError] if [TreeNodeBuildInfo.metadata] already contains a key
  /// that is in [metadata].
  NodeBuildInfoBuilder metadata(Map<String, Object> metadata) {
    for (var pair in metadata.entries) {
      if (_metadata.containsKey(pair.key)) {
        throw StateError(
            'Node "$nodeKey" already has metadata with key "${pair.key}"');
      }
      _metadata[pair.key] = pair.value;
    }

    return this;
  }

  /// Adds [filter] to [TreeNodeBuildInfo.filters].
  NodeBuildInfoBuilder filter(TreeStateFilter filter) {
    _filters.add(filter);
    return this;
  }
}
