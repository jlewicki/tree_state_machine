import 'package:meta/meta.dart';

import '../data_provider.dart';
import '../tree_node.dart';
import '../tree_state.dart';
import 'tree_build_context.dart';

/// A description of the root node in a state tree.
///
/// In addition to describing the [TreeState] that provides the message handling behavior of the
/// root node, the properties of [Root] decribe how the root node relates to other nodes in the
/// tree. For example, [children] describe the child nodes of the root, and [initialChild]
/// describes which child node should be entered when the root node is entered.
///
/// The following example describes a state tree that includes each kind of node ([Root],
/// [Interior], and [Leaf]):
///
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
  /// automatically created using the type name of `T` as the key name.
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
  final Iterable<NodeBuilder<FinalNode>> finals;

  /// Constructs a [Root].
  ///
  /// [createState], [children], and [initialChild] must not be null.
  Root({
    StateKey key,
    @required this.createState,
    @required this.children,
    @required this.initialChild,
    Iterable<NodeBuilder<FinalNode>> finals,
  })  : key = key ?? StateKey.forState<T>(),
        finals = finals ?? const [] {
    assert(createState != null);
    assert(children != null);
    assert(initialChild != null);
  }

  @override
  TreeNode build(TreeBuildContext context) => context.buildRoot<T>(
        key,
        createState,
        children,
        initialChild,
        finals,
      );
}

/// Describes how to build a root node in a state tree, with associated state data of type `D`.
///
/// [RootWithData] behaves similarly to [Root], except that a function to create the [DataProvider]
/// that manages the data for the state must be provided.
///
/// See also:
///
///   * [DataTreeState], which is a tree state that has associated state data.
///   * [DataProvider], which mediates access to the state data.
@sealed
@immutable
class RootWithData<T extends DataTreeState<D>, D> extends Root<T> {
  /// Function used to create the [DataProvider] that manages the data for the state.
  final DataProvider<D> Function() createProvider;

  /// Constructs a [RootWithData].
  ///
  /// [createState], [children], [initialChild], and [createProvider] must not be null.
  RootWithData({
    StateKey key,
    @required DataStateCreator<T, D> createState,
    @required Iterable<NodeBuilder<ChildNode>> children,
    @required InitialChild initialChild,
    @required this.createProvider,
    Iterable<NodeBuilder<FinalNode>> finals,
  }) : super(
            key: key,
            createState: createState,
            initialChild: initialChild,
            children: children,
            finals: finals) {
    assert(createProvider != null);
  }

  @override
  TreeNode build(TreeBuildContext context) => context.buildRootWithData<T, D>(
        key,
        createState,
        createProvider,
        children,
        initialChild,
        finals,
      );
}

/// Describes how to build an interior state in a state tree.
///
/// An interior node is a parent of a collection of child node. Note that an interior node is
/// distinct from the root node, even though the root node also has child nodes.
@sealed
@immutable
class Interior<T extends TreeState> implements NodeBuilder<InteriorNode> {
  /// The key that uniquely identifies the node within the tree.
  ///
  /// The key is optional when constructing the [Interior]. If it is not provided, a key will be
  /// automatically created using the type name of `T`as the key name.
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
    StateKey key,
    @required this.createState,
    @required this.children,
    @required this.initialChild,
  }) : key = key ?? StateKey.forState<T>() {
    assert(createState != null);
    assert(children != null);
    assert(initialChild != null);
  }

  @override
  TreeNode build(TreeBuildContext context) =>
      context.buildInterior<T>(key, createState, children, initialChild);
}

/// Describes how to build an interior node in a state tree, with associated state data of type
/// `D`.
///
/// An interior node is a parent of a collection of child node. Note that an interior node is
/// distinct from the root node, even though the root node also has child nodes.
///
/// [InteriorWithData] behaves similarly to [Interior], except that a function to create the [DataProvider]
/// that manages the data for the state must be provided.
///
/// See also:
///
///   * [DataTreeState], which is a tree state that has associated state data.
///   * [DataProvider], which mediates access to the state data.
@sealed
@immutable
class InteriorWithData<T extends DataTreeState<D>, D> extends Interior<T> {
  /// Function used to create the [DataProvider] that manages the data for the state.
  final DataProvider<D> Function() createProvider;

  InteriorWithData({
    StateKey key,
    @required DataStateCreator<T, D> createState,
    @required Iterable<NodeBuilder<ChildNode>> children,
    @required InitialChild initialChild,
    @required this.createProvider,
  }) : super(
          key: key,
          createState: createState,
          children: children,
          initialChild: initialChild,
        ) {
    assert(createProvider != null);
  }

  @override
  TreeNode build(TreeBuildContext context) =>
      context.buildInteriorWithData<T, D>(key, createState, children, initialChild, createProvider);
}

/// Describes how to build a leaf node in a state tree.
@sealed
@immutable
class Leaf<T extends TreeState> implements NodeBuilder<LeafNode> {
  /// The key that uniquely identifies the node within the tree.
  ///
  /// The key is optional when constructing the [Leaf]. If it is not provided, a key will be
  /// automatically created using the type name of `T` as the key name.
  final StateKey key;

  /// Function used to create the [TreeState] of type `T` that defines the behavior of the leaf
  /// node.
  ///
  /// The function is provided the [key] that identifies this node.
  final StateCreator<T> createState;

  /// Constructs a [Leaf].
  ///
  /// [createState] must not be null.
  Leaf({
    StateKey key,
    @required this.createState,
  }) : key = key ?? StateKey.forState<T>() {
    assert(createState != null);
  }

  @override
  TreeNode build(TreeBuildContext context) => context.buildLeaf<T>(key, createState);
}

/// Describes how to build a leaf node in a state tree, with associated state data of type `D`.
///
/// [LeafWithData] behaves similarly to [Leaf], except that a function to create the [DataProvider]
/// that manages the data for the state must be provided.
///
/// See also:
///
///   * [DataTreeState], which is a tree state that has associated state data.
///   * [DataProvider], which mediates access to the state data.
@sealed
@immutable
class LeafWithData<T extends DataTreeState<D>, D> extends Leaf<T> {
  final OwnedDataProvider<D> Function() createProvider;

  /// Constructs a [LeafWithData].
  ///
  /// [createState] and [createProvider] must not be null.
  LeafWithData({
    StateKey key,
    @required DataStateCreator<T, D> createState,
    @required this.createProvider,
  }) : super(key: key, createState: createState) {
    assert(createProvider != null);
  }

  @override
  TreeNode build(TreeBuildContext context) =>
      context.buildLeafWithData<T, D>(key, createState, createProvider);
}

/// Describes how to build a leaf node in a state tree.
///
/// A final node is a special kind of [LeafNode]. When a final node becomes the current state in a
/// [TreeStateMachine], the state machine is considered ended, and no further message handling or
/// state transitions will occur.
@sealed
@immutable
class Final<T extends FinalTreeState> implements NodeBuilder<FinalNode> {
  /// The key that uniquely identifies the node within the tree.
  ///
  /// The key is optional when constructing the [Final]. If it is not provided, a key will be
  /// automatically created using the type name of [T] as the key name.
  final StateKey key;

  /// Function used to create the [TreeState] of type `T` that defines the behavior of the final
  /// node.
  ///
  /// The function is provided the [key] that identifies this node.
  final StateCreator<T> createState;

  /// Constructs a [Final].
  ///
  /// [createState] must not be null.
  Final({
    @required this.createState,
    StateKey key,
  }) : key = key ?? StateKey.forState<T>() {
    assert(createState != null);
  }

  @override
  TreeNode build(TreeBuildContext context) => context.buildLeaf<T>(key, createState, isFinal: true);
}
