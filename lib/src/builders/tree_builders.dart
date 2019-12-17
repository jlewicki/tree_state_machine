import 'package:meta/meta.dart';

import '../data_provider.dart';
import '../tree_node.dart';
import '../tree_state.dart';
import '../utility.dart';
import 'tree_build_context.dart';

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
    return context.buildRoot<T>(
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
    return context.buildRoot<T>(
      key,
      (key) {
        final lazyProvider = Lazy(createProvider);
        return TreeNode.root(
          key,
          context.stateCreatorWithDataInitialization(
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
  final StateKey key;

  Interior({
    @required this.createState,
    @required this.children,
    @required this.initialChild,
    this.key,
  });

  @override
  TreeNode build(TreeBuildContext context) {
    return context.buildInterior<T>(
      key,
      (key) => TreeNode.interior(key, context.parentNode, createState, initialChild),
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
  TreeNode build(TreeBuildContext context) {
    return context.buildInterior<T>(
      key,
      (key) {
        final lazyProvider = Lazy(createProvider);
        return TreeNode.interior(
          key,
          context.parentNode,
          context.stateCreatorWithDataInitialization(
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
  TreeNode build(TreeBuildContext context) {
    return context.buildLeaf<T>(
      key,
      (k) => TreeNode.leaf(k, context.parentNode, createState),
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
  TreeNode build(TreeBuildContext context) {
    return context.buildLeaf<T>(
      key,
      (k) {
        final lazyProvider = Lazy(createProvider);
        return TreeNode.leaf(
          k,
          context.parentNode,
          context.stateCreatorWithDataInitialization(
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
  TreeNode build(TreeBuildContext context) {
    return context.buildLeaf<T>(
      key,
      (k) => TreeNode.finalNode(k, context.parentNode, createState),
    );
  }
}
