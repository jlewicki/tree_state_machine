part of '../../tree_builders.dart';

/// Type of functions that can create a [TreeNode].
typedef TreeNodeBuilder = TreeNode Function(TreeBuildContext context);

/// Provides a description of how a [TreeNode] should be built.
class TreeNodeBuildInfo {
  TreeNodeBuildInfo(
    this.key,
    this.createState, {
    this.initialChild,
    this.childBuilders = const [],
    this.isFinalState = false,
    this.dataCodec,
    this.filters = const [],
    this.metadata = const {},
  });

  final StateKey key;
  final StateCreator createState;
  final Iterable<TreeNodeBuilder> childBuilders;
  final GetInitialChild? initialChild;
  final StateDataCodec<dynamic>? dataCodec;
  final List<TreeStateFilter> filters;
  final Map<String, Object> metadata;
  final bool isFinalState;
}

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This interface is infrastructure, and is not intended to be called by application code.
class TreeBuildContext {
  TreeBuildContext._(this.parentNode, this.nodes);

  /// Constructs a [TreeBuildContext].
  factory TreeBuildContext() => TreeBuildContext._(null, {});

  /// The current parent node for nodes that will be built.
  final TreeNode? parentNode;

  /// Map of nodes that have been built.
  final Map<StateKey, TreeNode> nodes;

  TreeNode buildRoot(TreeNodeBuildInfo nodeBuildInfo) {
    assert(parentNode == null);
    assert(nodeBuildInfo.initialChild != null);
    assert(nodeBuildInfo.childBuilders.isNotEmpty);
    assert(!nodes.containsKey(nodeBuildInfo.key));

    var children = <TreeNode>[];
    var node = TreeNode(
      nodeBuildInfo.key,
      createState: nodeBuildInfo.createState,
      getInitialChild: nodeBuildInfo.initialChild,
      children: children,
      dataCodec: nodeBuildInfo.dataCodec,
      filters: nodeBuildInfo.filters,
      metadata: nodeBuildInfo.metadata,
    );

    final childCtx = _childBuildContext(node);
    children.addAll(
        nodeBuildInfo.childBuilders.map((buildChild) => buildChild(childCtx)));
    _addNode(node);

    // Every state tree needs a 'Stopped' state, which is entered when 'Stop' is called on a
    // tree state machine.
    var stoppedNode = _buildStoppedNode(node);
    _addNode(stoppedNode);

    return node;
  }

  TreeNode buildInterior(TreeNodeBuildInfo nodeBuildInfo) {
    assert(parentNode != null);
    assert(nodeBuildInfo.initialChild != null);
    assert(nodeBuildInfo.childBuilders.isNotEmpty);

    var children = <TreeNode>[];
    var node = TreeNode(
      nodeBuildInfo.key,
      createState: nodeBuildInfo.createState,
      parent: parentNode,
      getInitialChild: nodeBuildInfo.initialChild,
      children: children,
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

  TreeNode buildLeaf(TreeNodeBuildInfo nodeBuildInfo) {
    assert(parentNode != null);
    assert(nodeBuildInfo.childBuilders.isEmpty);

    var node = TreeNode(
      nodeBuildInfo.key,
      createState: nodeBuildInfo.createState,
      parent: parentNode,
      isFinal: nodeBuildInfo.isFinalState,
      dataCodec: nodeBuildInfo.dataCodec,
      filters: nodeBuildInfo.filters,
      metadata: nodeBuildInfo.metadata,
    );

    _addNode(node);
    return node;
  }

  /// Creates a tree node representing the 'exterally stopped' state, which is entered when stop() is
  /// called on a tree state machine.
  TreeNode _buildStoppedNode(TreeNode rootNode) {
    return TreeNode(
      stoppedStateKey,
      createState: (_) => _stoppedState,
      parent: rootNode,
      isFinal: true,
    );
  }

  void _addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg =
          'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }

  // Constructs a [TreeBuildContext] that adusts the current parent node, so child nodes can be
  /// built.
  TreeBuildContext _childBuildContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes);
}

final _stoppedState = DelegatingTreeState(
  (ctx) => throw StateError('Can not send message to a final state'),
  (ctx) => {},
  (ctx) => throw StateError('Can not leave a final state.'),
  null,
);
