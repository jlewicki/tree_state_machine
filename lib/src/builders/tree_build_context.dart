import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/utility.dart';

import '../data_provider.dart';
import '../tree_node.dart';
import '../tree_state.dart';

/// Base interface for types that identity the types of [TreeNode] in a state tree.
class NodeKind {}

/// Labels a [NodeBuilder] as one that creates a root node.
class RootNode implements NodeKind {}

/// Labels a [NodeBuilder] as one that creates a child node.
///
/// A child node is an a node that can be a child of another node. That is, a child node is either
/// an [InteriorNode], a [LeafNode], or a [FinalNode].
class ChildNode implements NodeKind {}

/// Labels a [NodeBuilder] as one that creates an interior node.
///
/// An interior node has both a parent node and child nodes. That is, a interior node is neither
/// an root node nor a leaf node.
class InteriorNode implements ChildNode {}

/// Labels a [NodeBuilder] as one that creates a leaf node.
///
/// A leaf node has a parent node but no child nodes. The current state of a [TreeStateMachine]
/// always belongs to a leaf node.
class LeafNode implements ChildNode {}

/// Labels a [NodeBuilder] as one that creates a final node.
///
/// A final node is a special kind of [LeafNode]. When a final node becomes the current state in a
/// [TreeStateMachine], the state machine is considered ended, and no further message handling or
/// state transitions will occur.
class FinalNode implements LeafNode {}

/// Defines a method for building a tree node of the [NodeKind] specified by `N`.
///
/// This interface is infrastructure, and is not intended to be called by application code.
abstract class NodeBuilder<N extends NodeKind> {
  /// Constructs a new [TreeNode] of the kind specified by `N`
  @factory
  TreeNode build(TreeBuildContext context);
}

/// Provides contextual information while a state tree is being constructed, and factory methods for
/// creating tree nodes.
///
/// This interface is infrastructure, and is not intended to be called by application code.
class TreeBuildContext {
  /// The current parent node for nodes that will be built.
  final TreeNode parentNode;

  /// Map of nodes that have been built.
  final HashMap<StateKey, TreeNode> nodes;

  /// [ObservableData<Object>] that provides access the state data of the current leaf node in
  /// the state machine.
  ///
  /// Note that this is not intended to be used directly until the [TreeStateMachine] is started.
  final ObservableData<Object> currentLeafData;

  TreeBuildContext._(this.parentNode, this.nodes, this.currentLeafData);

  /// Constructs a [TreeBuildContext].
  factory TreeBuildContext(ObservableData<Object> currentLeafData, [TreeNode parentNode]) =>
      TreeBuildContext._(
        parentNode,
        HashMap(),
        currentLeafData,
      );

  /// Constructs a [TreeBuildContext] that adusts the current parent node, so child nodes can be
  /// built.
  TreeBuildContext childContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes, currentLeafData);

  /// Builds a root node.
  TreeNode buildRoot<T extends TreeState>(
    StateKey key,
    StateCreator<T> createState,
    Iterable<NodeBuilder<ChildNode>> children,
    InitialChild initialChild,
    Iterable<NodeBuilder<FinalNode>> finalStates,
  ) {
    return _buildRoot(TreeNode.root(key, createState, initialChild), children, finalStates);
  }

  /// Builds a root node with associated state data.
  TreeNode buildRootWithData<T extends DataTreeState<D>, D>(
    StateKey key,
    StateCreator<T> createState,
    DataProvider<D> Function() createProvider,
    Iterable<NodeBuilder<ChildNode>> children,
    InitialChild initialChild,
    Iterable<NodeBuilder<FinalNode>> finalStates,
  ) {
    final provider = Lazy(createProvider);
    return _buildRoot(
        TreeNode.root(
          key,
          _stateCreatorWithDataInitialization(createState, provider, currentLeafData),
          initialChild,
          provider,
        ),
        children,
        finalStates);
  }

  /// Builds an interior node.
  TreeNode buildInterior<T extends TreeState>(
    StateKey key,
    StateCreator<T> createState,
    Iterable<NodeBuilder<ChildNode>> children,
    InitialChild initialChild,
  ) {
    return _buildInterior(
      TreeNode.interior(key, parentNode, createState, initialChild),
      children,
    );
  }

  /// Builds an interior node with associated state data.
  TreeNode buildInteriorWithData<T extends DataTreeState<D>, D>(
    StateKey key,
    StateCreator<T> createState,
    Iterable<NodeBuilder<ChildNode>> children,
    InitialChild initialChild,
    DataProvider<D> Function() createProvider,
  ) {
    final provider = Lazy(createProvider);
    return _buildInterior(
      TreeNode.interior(
        key,
        parentNode,
        _stateCreatorWithDataInitialization(createState, provider, currentLeafData),
        initialChild,
        provider,
      ),
      children,
    );
  }

  /// Builds a leaf node
  TreeNode buildLeaf<T extends TreeState>(
    StateKey key,
    StateCreator<T> createState, {
    bool isFinal = false,
  }) {
    return _buildLeaf(isFinal
        ? TreeNode.finalNode(key, parentNode, createState)
        : TreeNode.leaf(key, parentNode, createState));
  }

  /// Builds a leaf node with associated state data.
  TreeNode buildLeafWithData<T extends DataTreeState<D>, D>(
    StateKey key,
    StateCreator<T> createState,
    OwnedDataProvider<D> Function() createProvider,
  ) {
    final provider = Lazy(createProvider);
    return _buildLeaf(TreeNode.leaf(
      key,
      parentNode,
      _stateCreatorWithDataInitialization(createState, provider, currentLeafData),
      provider,
    ));
  }

  TreeNode _buildRoot(
    TreeNode root,
    Iterable<NodeBuilder<ChildNode>> children,
    Iterable<NodeBuilder<FinalNode>> finalStates,
  ) {
    if (parentNode != null) {
      throw StateError('Unexpected parent node in context when building root node');
    }
    final childCtx = childContext(root);
    root.children.addAll(children.map((childBuilder) => childBuilder.build(childCtx)));
    if (finalStates != null) {
      root.children.addAll(finalStates.map((childBuilder) => childBuilder.build(childCtx)));
    }
    _addNode(root);
    return root;
  }

  TreeNode _buildInterior(
    TreeNode interior,
    Iterable<NodeBuilder<ChildNode>> children,
  ) {
    final childCtx = childContext(interior);
    interior.children.addAll(children.map((childBuilder) => childBuilder.build(childCtx)));
    _addNode(interior);
    return interior;
  }

  TreeNode _buildLeaf(TreeNode leaf) {
    _addNode(leaf);
    return leaf;
  }

  StateCreator _stateCreatorWithDataInitialization<T extends DataTreeState<D>, D>(
    DataStateCreator<T, D> createState,
    Lazy<DataProvider<D>> lazyProvider,
    ObservableData<Object> leafData,
  ) =>
      (key) {
        final state = createState(key);
        final provider = lazyProvider.value;
        if (provider is CurrentLeafDataProvider) {
          (provider as CurrentLeafDataProvider).initializeLeafData(leafData);
        }
        state.initializeDataValue(provider);
        return state;
      };

  void _addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}
