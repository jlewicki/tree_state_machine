part of tree_builders;

/// Type of functions that can create a tree node.
typedef _NodeBuilder = TreeNode Function(TreeBuildContext context);

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This interface is infrastructure, and is not intended to be called by application code.
class TreeBuildContext {
  /// The current parent node for nodes that will be built.
  final TreeNode? parentNode;

  /// Map of nodes that have been built.
  final HashMap<StateKey, TreeNode> nodes;

  TreeBuildContext._(this.parentNode, this.nodes);

  /// Constructs a [TreeBuildContext].
  factory TreeBuildContext() => TreeBuildContext._(null, HashMap());

  /// Constructs a [TreeBuildContext] that adusts the current parent node, so child nodes can be
  /// built.
  TreeBuildContext _childContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes);

  TreeNode _buildRoot(
    StateKey key,
    StateCreator createState,
    Iterable<_NodeBuilder> children,
    GetInitialChild initialChild,
    StateDataCodec? codec,
  ) {
    assert(parentNode == null);
    var node = TreeNode(NodeType.rootNode, key, parentNode, createState, codec, initialChild);
    final childCtx = _childContext(node);
    node.children.addAll(children.map((buildChild) => buildChild(childCtx)));
    _addNode(node);
    return node;
  }

  TreeNode _buildInterior(
    StateKey key,
    StateCreator createState,
    Iterable<_NodeBuilder> children,
    GetInitialChild initialChild,
    StateDataCodec? codec,
  ) {
    assert(parentNode != null);
    var node = TreeNode(NodeType.interiorNode, key, parentNode!, createState, codec, initialChild);
    final childCtx = _childContext(node);
    node.children.addAll(children.map((buildChild) => buildChild(childCtx)));
    _addNode(node);
    return node;
  }

  TreeNode _buildLeaf(
    StateKey key,
    StateCreator createState,
    StateDataCodec? codec, {
    bool isFinal = false,
  }) {
    assert(parentNode != null);
    var node = isFinal
        ? TreeNode(NodeType.finalLeafNode, key, parentNode!, createState, codec)
        : TreeNode(NodeType.leafNode, key, parentNode!, createState, codec);
    _addNode(node);
    return node;
  }

  void _addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}
