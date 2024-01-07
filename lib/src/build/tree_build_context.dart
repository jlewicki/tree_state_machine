import 'package:tree_state_machine/tree_state_machine.dart';
import 'tree_node_info.dart';
import 'tree_node.dart';

/// Function that can augment a [TreeNodeInfo] using the provided [NodeInfoBuilder].
typedef ExtendNodeInfo = void Function(NodeInfoBuilder);

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This is a low-level feature and will not be needed by most applications.
class TreeBuildContext {
  TreeBuildContext._(
      this._parent, this._nodes, this.extendNodes, this._addStoppedState);

  /// Constructs a [TreeBuildContext].
  factory TreeBuildContext({
    ExtendNodeInfo? extendNodes,
    bool addStoppedState = true,
  }) =>
      TreeBuildContext._(null, {}, extendNodes, addStoppedState);

  /// The current parent node for nodes that will be built.
  final TreeNode? _parent;

  /// Map of nodes that have been built.
  final Map<StateKey, TreeNode> _nodes;

  /// Map of nodes that have been built by this context.
  Map<StateKey, TreeNodeInfo> get nodes => {
        for (var e in _nodes.entries)
          if (e.key != stoppedStateKey) e.key: e.value.info
      };

  final bool _addStoppedState;

  /// If provided, this function is called each time this context builds a tree node. The function
  /// is provided the [NodeInfoBuilder] that can be used to augment the existing
  /// [TreeNodeInfo] before it is used to construct a node.
  ///
  /// This is a low-level feature inteded to support general purpose extensions, and will not
  /// typically be used.
  ExtendNodeInfo? extendNodes;

  /// Creates a root [TreeNode] that is fully populated with its descendant nodes, based on the
  /// description provided by [rootInfo].
  TreeNode buildTree(RootNodeInfo rootInfo) {
    return _buildNode(rootInfo);
  }

  TreeNode _buildNode(TreeNodeInfo nodeInfo) {
    return switch (nodeInfo) {
      RootNodeInfo() => _buildRoot(nodeInfo),
      InteriorNodeInfo() => _buildInterior(nodeInfo),
      LeafNodeInfo() => _buildLeaf(nodeInfo)
    };
  }

  TreeNode _buildRoot(RootNodeInfo nodeInfo) {
    assert(_parent == null);
    assert(nodeInfo.children.isNotEmpty);

    nodeInfo = _transformRoot(nodeInfo);

    var children = <TreeNode>[];
    var node = TreeNode(nodeInfo, parent: null, children: children);
    var childCtx = _childContext(node);
    var childInfos = nodeInfo.children
        .followedBy(_addStoppedState ? [_stoppedStateInfo(nodeInfo)] : []);
    children.addAll(childInfos.map(childCtx._buildNode));

    _addNode(node);
    return node;
  }

  TreeNode _buildInterior(InteriorNodeInfo nodeInfo) {
    assert(_parent != null);
    assert(nodeInfo.children.isNotEmpty);

    nodeInfo = _transformInterior(nodeInfo);

    var children = <TreeNode>[];
    var node = TreeNode(nodeInfo, parent: _parent, children: children);
    var childCtx = _childContext(node);
    children.addAll(nodeInfo.children.map(childCtx._buildNode));

    _addNode(node);
    return node;
  }

  TreeNode _buildLeaf(LeafNodeInfo nodeInfo) {
    assert(_parent != null);

    nodeInfo = _transformLeaf(nodeInfo);
    var node = TreeNode(nodeInfo, parent: _parent, children: const []);
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

  TreeBuildContext _childContext(TreeNode newParentNode) {
    return TreeBuildContext._(newParentNode, _nodes, extendNodes, false);
  }

  RootNodeInfo _transformRoot(RootNodeInfo node) {
    var transformBuilder = _applyTransform(node);
    return transformBuilder != null
        ? RootNodeInfo(
            node.key,
            node.createState,
            children: node.children,
            initialChild: node.initialChild,
            dataCodec: node.dataCodec,
            filters: transformBuilder._filters,
            metadata: transformBuilder._metadata,
          )
        : node;
  }

  InteriorNodeInfo _transformInterior(InteriorNodeInfo node) {
    var transformBuilder = _applyTransform(node);
    return transformBuilder != null
        ? InteriorNodeInfo(
            node.key,
            node.createState,
            parent: node.parent,
            children: node.children,
            initialChild: node.initialChild,
            dataCodec: node.dataCodec,
            filters: transformBuilder._filters,
            metadata: transformBuilder._metadata,
          )
        : node;
  }

  LeafNodeInfo _transformLeaf(LeafNodeInfo node) {
    var transformBuilder = _applyTransform(node);
    return transformBuilder != null
        ? LeafNodeInfo(
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

  NodeInfoBuilder? _applyTransform(TreeNodeInfo nodeBuildInfo) {
    if (extendNodes == null) {
      return null;
    }

    var transformBuilder = NodeInfoBuilder(
      nodeBuildInfo,
      Map.from(nodeBuildInfo.metadata),
      List.from(nodeBuildInfo.filters),
    );

    extendNodes!(transformBuilder);

    return transformBuilder;
  }

  LeafNodeInfo _stoppedStateInfo(RootNodeInfo rootNodeInfo) {
    return LeafNodeInfo(
      stoppedStateKey,
      (key) => _stoppedState,
      parent: rootNodeInfo,
      isFinalState: true,
    );
  }
}

/// Provides methods for augmenting a [TreeNodeInfo] value with additional information.
class NodeInfoBuilder {
  /// Constructs a [NodeInfoBuilder].
  NodeInfoBuilder(this.nodeBuildInfo, this._metadata, this._filters);

  /// Identifies the [TreeNodeInfo] to which this builder applies.
  final TreeNodeInfo nodeBuildInfo;

  final List<TreeStateFilter> _filters;
  final Map<String, Object> _metadata;

  /// Adds all entries in [metadata] to [TreeNodeInfo.metadata].
  ///
  /// Throws [StateError] if [TreeNodeInfo.metadata] already contains a key
  /// that is in [metadata].
  NodeInfoBuilder metadata(Map<String, Object> metadata) {
    for (var pair in metadata.entries) {
      if (_metadata.containsKey(pair.key)) {
        throw StateError(
            'Node "${nodeBuildInfo.key}" already has metadata with key "${pair.key}"');
      }
      _metadata[pair.key] = pair.value;
    }

    return this;
  }

  /// Adds [filter] to [TreeNodeInfo.filters].
  NodeInfoBuilder filter(TreeStateFilter filter) {
    _filters.add(filter);
    return this;
  }
}

final _stoppedState = DelegatingTreeState(
  onMessage: (ctx) => throw StateError('Can not send message to a final state'),
  onEnter: emptyTransitionHandler,
  onExit: (ctx) => throw StateError('Can not leave a final state.'),
);
