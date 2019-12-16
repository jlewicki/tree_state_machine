import 'dart:collection';

import 'package:meta/meta.dart';

import '../data_provider.dart';
import '../tree_node_2.dart';
import '../tree_state.dart';
import '../utility.dart';

class TaggedNode {}

class RootNode extends TaggedNode {}

class ChildNode extends TaggedNode {}

class InteriorNode extends ChildNode {}

class LeafNode extends ChildNode {}

class FinalNode extends LeafNode {}

abstract class NodeBuilder<N extends TaggedNode> {
  TreeNode build(TreeBuildContext context);
}

class TreeBuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;
  final ObservableData<Object> currentLeafData;

  TreeBuildContext._(this.parentNode, this.nodes, this.currentLeafData);

  factory TreeBuildContext(ObservableData<Object> currentLeafData, [TreeNode parentNode]) =>
      TreeBuildContext._(parentNode, HashMap(), currentLeafData);

  TreeBuildContext childContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes, currentLeafData);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}

/// A definition of the root node in a state tree.
///
/// When a [TreeStateMachine] is started, it will use this definition to create the tree of nodes
/// that controls the behavior of the state machine.
@sealed
@immutable
class Root<T extends TreeState> implements NodeBuilder<RootNode> {
  /// The key that uniquely identifies the node within the tree.
  final StateKey key;

  /// Function used to create the [TreeState] that defines the behavior of the root node.
  final StateCreator<T> createState;

  /// Builders that will create the child states of this root node.
  ///
  /// The root node always has a least one child node.
  final Iterable<NodeBuilder<ChildNode>> children;

  /// Function that selects the initial child state, when the root state is entered.
  final InitialChild initialChild;

  /// Builders that will create the final states (if any) of this root node.
  final Iterable<NodeBuilder<FinalNode>> finalStates;

  /// Constructs a [Root].
  ///
  /// [createState], [children], and [initialChild] must not be null.
  Root({
    @required this.createState,
    @required this.children,
    @required this.initialChild,
    StateKey key,
    Iterable<NodeBuilder<FinalNode>> finalStates,
  })  : key = key ?? StateKey.forState<T>(),
        finalStates = finalStates ?? const [];

  @override
  TreeNode build(TreeBuildContext context) {
    return buildRoot<T>(
      context,
      key,
      (key) => TreeNode.root(key, createState, initialChild),
      children,
      initialChild,
      finalStates,
    );
  }
}

/// Describes how to build a root node with associated state data in a state tree.
@sealed
@immutable
class RootWithData<T extends DataTreeState<D>, D> implements NodeBuilder<RootNode> {
  final DataStateCreator<T, D> createState;
  final Iterable<NodeBuilder<ChildNode>> children;
  final InitialChild initialChild;
  final DataProvider<D> Function() createProvider;
  final StateKey key;
  final Iterable<NodeBuilder<FinalNode>> finalStates;

  RootWithData({
    @required this.createState,
    @required this.children,
    @required this.initialChild,
    @required this.createProvider,
    this.key,
    this.finalStates,
  });

  @override
  TreeNode build(TreeBuildContext context) {
    return buildRoot<T>(
      context,
      key,
      (key) {
        final lazyProvider = Lazy(createProvider);
        return TreeNode.root(
          key,
          stateCreatorWithDataInitialization(
              createState, lazyProvider.value, context.currentLeafData),
          initialChild,
          lazyProvider.value,
        );
      },
      children,
      initialChild,
      finalStates,
    );
  }
}

/// Describes how to build an interior state in a state tree.
///
/// An interior state is a parent of a collection of child states. Note that an interior state is
/// distinct from a root state, even though a root state also has child states.
@sealed
@immutable
class Interior<T extends TreeState> implements NodeBuilder<InteriorNode> {
  final StateCreator<T> createState;
  final Iterable<NodeBuilder<ChildNode>> children;
  final InitialChild initialChild;
  final key;

  Interior({
    @required this.createState,
    @required this.children,
    @required this.initialChild,
    this.key,
  });

  @override
  InteriorNode build(TreeBuildContext context) {
    return buildInterior<T>(
      context,
      key,
      (key) => InteriorNode(key, context.parentNode, createState, initialChild),
      children,
    );
  }
}

/// Describes how to build an interior state with associated state data in a state tree.
///
/// An interior state is a parent of a collection of child states. Note that an interior state is
/// distinct from a root state, even though a root state also has child states.
@sealed
@immutable
class InteriorWithData<T extends DataTreeState<D>, D> implements NodeBuilder<InteriorNode> {
  final DataStateCreator<T, D> createState;
  final Iterable<NodeBuilder<ChildNode>> children;
  final InitialChild initialChild;
  final DataProvider<D> Function() createProvider;
  final StateKey key;

  InteriorWithData({
    @required this.createState,
    @required this.children,
    @required this.initialChild,
    @required this.createProvider,
    this.key,
  });

  @override
  InteriorNode build(TreeBuildContext context) {
    return buildInterior<T>(
      context,
      key,
      (key) {
        final lazyProvider = Lazy(createProvider);
        return InteriorNode(
          key,
          context.parentNode,
          stateCreatorWithDataInitialization(
              createState, lazyProvider.value, context.currentLeafData),
          initialChild,
          lazyProvider.value,
        );
      },
      children,
    );
  }
}

@sealed
@immutable
class Leaf<T extends TreeState> implements NodeBuilder<LeafNode> {
  final StateCreator<T> createState;
  final StateKey key;

  Leaf({
    @required this.createState,
    this.key,
  });

  @override
  LeafNode build(TreeBuildContext context) {
    return buildLeaf<T>(
      context,
      key,
      (k) => LeafNode(k, context.parentNode, createState),
    );
  }
}

@sealed
@immutable
class LeafWithData<T extends DataTreeState<D>, D> implements NodeBuilder<LeafNode> {
  final DataStateCreator<T, D> createState;
  final OwnedDataProvider<D> Function() createProvider;
  final StateKey key;

  LeafWithData({
    @required this.createState,
    @required this.createProvider,
    this.key,
  });

  @override
  LeafNode build(TreeBuildContext context) {
    return buildLeaf<T>(
      context,
      key,
      (k) {
        final lazyProvider = Lazy(createProvider);
        return LeafNode(
          k,
          context.parentNode,
          stateCreatorWithDataInitialization(
              createState, lazyProvider.value, context.currentLeafData),
          lazyProvider.value,
        );
      },
    );
  }
}

@sealed
@immutable
class Final<T extends FinalTreeState> implements NodeBuilder<FinalNode> {
  final StateCreator<T> createState;
  final StateKey key;

  Final({
    @required this.createState,
    this.key,
  });

  @override
  FinalNode build(TreeBuildContext context) {
    return buildLeaf<T>(
      context,
      key,
      (k) => FinalNode(k, context.parentNode, createState),
    );
  }
}

TreeNode buildRoot<T extends TreeState>(
  TreeBuildContext ctx,
  StateKey key,
  TreeNode Function(StateKey) createNode,
  Iterable<NodeBuilder<ChildNode>> children,
  InitialChild initialChild,
  Iterable<NodeBuilder<FinalNode>> finalStates,
) {
  if (ctx.parentNode != null) {
    throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
  }
  final nodeKey = key ?? StateKey.forState<T>();
  final root = createNode(nodeKey);
  final childContext = ctx.childContext(root);
  root.children.addAll(children.map((childBuilder) => childBuilder.build(childContext)));
  if (finalStates != null) {
    root.children.addAll(finalStates.map((childBuilder) => childBuilder.build(childContext)));
  }
  ctx.addNode(root);
  return root;
}

InteriorNode buildInterior<T extends TreeState>(
  TreeBuildContext ctx,
  StateKey key,
  InteriorNode Function(StateKey) createNode,
  Iterable<NodeBuilder<ChildNode>> children,
) {
  final nodeKey = key ?? StateKey.forState<T>();
  final interior = createNode(nodeKey);
  final childContext = ctx.childContext(interior);
  interior.children.addAll(children.map((childBuilder) => childBuilder.build(childContext)));
  ctx.addNode(interior);
  return interior;
}

LeafNode buildLeaf<T extends TreeState>(
  TreeBuildContext ctx,
  StateKey key,
  LeafNode Function(StateKey) createNode,
) {
  final nodeKey = key ?? StateKey.forState<T>();
  final leaf = createNode(nodeKey);
  ctx.addNode(leaf);
  return leaf;
}

StateCreator stateCreatorWithDataInitialization<T extends DataTreeState<D>, D>(
  DataStateCreator<T, D> createState,
  DataProvider<D> provider,
  ObservableData<Object> leafData,
) =>
    (key) {
      final state = createState(key);
      if (provider is CurrentLeafDataProvider) {
        (provider as CurrentLeafDataProvider).initializeLeafData(leafData);
      }
      state.initializeDataValue(provider);
      return state;
    };
