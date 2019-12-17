import 'package:meta/meta.dart';

import '../data_provider.dart';
import '../tree_node.dart';
import '../tree_state.dart';
import '../utility.dart';
import 'tree_build_context.dart';

/// A definition of the root node in a state tree.
///
/// In addition to defining the [TreeState] that provides the message handling behavior of the root
/// node, the properties of [Root] decribe how the root node relates to other nodes in the tree. For
/// example, [children] describe the child nodes of the root, and [initialChild] describes which
/// child node should be entered when the child node is entered.
///
/// The following example shows the defintition of a state tree that includes each kind of node:
/// ```dart
/// var treeBuilder = Root(
///   createState: (key) => MyRootState(),
///   initialChild: (transitionContext) => StateKey.forState<MyLeafState1>(),
///   children: [
///     Interior(
///       createState: (key) => MyInteriorState(),
///       initialChild: (transitionContext) => StateKey.forState<MyLeafState1>(),
///       children: [
///         Leaf(createState: (key) => MyLeafState1()),
///         Leaf(createState: (key) => MyLeafState2()),
///       ]
///     ),
///     Leaf(createState: (key) => MyLeafState3()),
///   ],
///   finalStates: [
///     Final(createState: (key) => MyFinalState()),
///   ],
/// );
/// ```
@sealed
@immutable
class Root<T extends TreeState> implements NodeBuilder<RootNode> {
  /// The key that uniquely identifies the node within the tree.
  ///
  /// The key is optional when constructing the [Root]. If it is not provided, a key will be
  /// automatically created using the type name of [T] as the key name.
  final StateKey key;

  /// Function used to create the [TreeState] of type `T` that defines the behavior of the root
  /// node.
  ///
  /// The function is provided the [key] that identifies this node.
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
        finalStates = finalStates ?? const [] {
    assert(createState != null);
    assert(children != null);
    assert(initialChild != null);
  }

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

/// Describes how to build a root node with associated state data iof type `D` in a state tree.
///
/// [RootWithData] behaves similarly to [Root], except that a function to create the [DataProvider]
/// that manages the data for the state must be provided.
@sealed
@immutable
class RootWithData<T extends DataTreeState<D>, D> implements NodeBuilder<RootNode> {
  /// The key that uniquely identifies the node within the tree.
  ///
  /// The key is optional when constructing the [Root]. If it is not provided, a key will be
  /// automatically created using the type name of [T] as the key name.
  final StateKey key;

  /// Function used to create the [TreeState] of type `T` that defines the behavior of the root
  /// node.
  ///
  /// The function is provided the [key] that identifies this node.
  final DataStateCreator<T, D> createState;

  /// Builders that will create the child states of this root node.
  ///
  /// The root node always has a least one child node.
  final Iterable<NodeBuilder<ChildNode>> children;

  /// Function that selects the initial child state, when the root state is entered.
  final InitialChild initialChild;

  /// Function used to create the [DataProvider] that manages the data for the state.
  final DataProvider<D> Function() createProvider;

  /// Builders that will create the final states (if any) of this root node.
  final Iterable<NodeBuilder<FinalNode>> finalStates;

  /// Constructs a [RootWithData].
  ///
  /// [createState], [children], [initialChild], and [createProvider] must not be null.
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
  /// The key that uniquely identifies the node within the tree.
  ///
  /// The key is optional when constructing the [Interior]. If it is not provided, a key will be
  /// automatically created using the type name of [T] as the key name.
  final StateKey key;

  /// Function used to create the [TreeState] of type `T` that defines the behavior of the interior
  /// node.
  ///
  /// The function is provided the [key] that identifies this node.
  final StateCreator<T> createState;

  /// Builders that will create the child states of this interior node.
  ///
  /// An interior node always has a least one child node.
  final Iterable<NodeBuilder<ChildNode>> children;

  /// Function that selects the initial child state, when the interior state is entered.
  final InitialChild initialChild;

  /// Constructs an [Interior].
  ///
  /// [createState], [children], and [initialChild] must not be null.
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
