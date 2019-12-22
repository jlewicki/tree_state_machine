import 'package:tree_state_machine/tree_state_helpers.dart';

import 'data_provider.dart';
import 'tree_state.dart';
import 'utility.dart';

enum NodeType { rootNode, interiorNode, leafNode, finalNode }

/// Type of functions that create a new [TreeState].
///
/// The function is passed the [StateKey] that identifies the new state.
typedef StateCreator<T extends TreeState> = T Function(StateKey key);

/// Type of functions that create a new [DataTreeState].
///
/// The function is passed the [StateKey] that identifies the new state.
typedef DataStateCreator<T extends DataTreeState<D>, D> = T Function(StateKey key);

/// Type of functions that select a child node to initially enter, when a parent node is entered.
///
/// The function is passed a [TransitionContext] that describes the transition that is currently
/// taking place.
typedef InitialChild = StateKey Function(TransitionContext ctx);

/// A node within a state tree.
///
/// While a [TreeState] defines the message processing behavior of a state, it does not model the
/// location of the state within a state tree (that is, a [TreeState] does not directly know its
/// parent or child states). Instead, [TreeNode] composes together a tree state along with
/// information about the location of the node with the tree.
class TreeNode {
  final NodeType nodeType;
  final Lazy<TreeState> _lazyState;
  final Lazy<DataProvider> _lazyProvider;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;

  TreeNode._(
    this.nodeType,
    this.key,
    this.parent,
    this._lazyState,
    this.initialChild,
    this._lazyProvider,
  );

  factory TreeNode.root(
    StateKey key,
    StateCreator createState,
    InitialChild initialChild, [
    Lazy<DataProvider> provider,
  ]) =>
      TreeNode._(
        NodeType.rootNode,
        key,
        null,
        Lazy<TreeState>(() => createState(key)),
        initialChild,
        provider,
      );

  factory TreeNode.interior(
    StateKey key,
    TreeNode parent,
    StateCreator<TreeState> createState,
    InitialChild initialChild, [
    Lazy<DataProvider> provider,
  ]) =>
      TreeNode._(
        NodeType.interiorNode,
        key,
        parent,
        Lazy<TreeState>(() => createState(key)),
        initialChild,
        provider,
      );

  factory TreeNode.leaf(
    StateKey key,
    TreeNode parent,
    StateCreator createState, [
    Lazy<DataProvider> provider,
  ]) =>
      TreeNode._(
        NodeType.leafNode,
        key,
        parent,
        Lazy<TreeState>(() => createState(key)),
        null,
        provider,
      );

  factory TreeNode.finalNode(
    StateKey key,
    TreeNode parent,
    StateCreator createState, [
    Lazy<DataProvider> provider,
  ]) =>
      TreeNode._(
        NodeType.finalNode,
        key,
        parent,
        Lazy<TreeState>(() => createState(key)),
        null,
        provider,
      );

  bool get isRoot => nodeType == NodeType.rootNode;
  bool get isLeaf => nodeType == NodeType.leafNode || nodeType == NodeType.finalNode;
  bool get isInterior => nodeType == NodeType.interiorNode;
  bool get isFinal => nodeType == NodeType.finalNode;

  /// The [TreeState] for this node, creating it if necessary.
  TreeState state() => _lazyState.value;

  /// The [DataProvider] for this node, creating it if necessary.
  ///
  /// Returns `null` if the node does not have an associated provider.
  DataProvider dataProvider() => _lazyProvider?.value;

  Lazy<DataProvider> get lazyProvider => _lazyProvider;

  /// Disposes this node and releases any associated resources.
  void dispose() {
    if (_lazyProvider?.hasValue ?? false) {
      _lazyProvider.value.dispose();
    }
  }

  /// Returns `true` if `stateKey` identifies this node, or one of its ancestor nodes.
  bool isSelfOrAncestor(StateKey stateKey) => selfOrAncestorWithKey(stateKey) != null;

  /// Lazily-compute the self-and-ancestor nodes of this node.
  ///
  /// The first node in the list is this node, and the last is the root node.
  Iterable<TreeNode> selfAndAncestors() sync* {
    yield this;
    yield* ancestors();
  }

  /// Lazily-compute the ancestor nodes of this node.
  ///
  /// The first node in the list is the parent of this node, and the last is the root node.
  Iterable<TreeNode> ancestors() sync* {
    var nextAncestor = parent;
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent;
    }
  }

  /// Finds the self-or-ancestor node that is identified `stateKey`.
  ///
  /// Returns `null` if there is no node that matches the key.
  TreeNode selfOrAncestorWithKey(StateKey stateKey) {
    assert(stateKey != null);
    return selfAndAncestors().firstWhere((n) => n.key == stateKey, orElse: () => null);
  }

  /// Finds the self-or-ancestor node that has a data provider whose data value matches type `D`.
  ///
  /// Returns `null` if there is no node that matches the data type.
  TreeNode selfOrAncestorWithData<D>() {
    return selfAndAncestors().firstWhere(
      (n) => n.dataProvider() is DataProvider<D>,
      orElse: () => null,
    );
  }

  /// Computes the least common ancestor node between this node and `other`.
  TreeNode lcaWith(TreeNode other) {
    assert(other != null);
    final i1 = selfAndAncestors().toList().reversed.iterator;
    final i2 = other.selfAndAncestors().toList().reversed.iterator;
    TreeNode lca;
    while (i1.moveNext() && i2.moveNext()) {
      lca = i1.current.key == i2.current.key ? i1.current : lca;
    }
    assert(lca != null, 'LCA must not be null');
    return lca;
  }

  /// The data value of type `D` associated with this node.
  ///
  /// Returns `null` if this node does not have a data provider.
  D data<D>() => selfOrAncestorDataStream<D>(key)?.value;

  DataStream<D> selfOrAncestorDataStream<D>([StateKey key]) {
    final node = key != null ? selfOrAncestorWithKey(key) : selfOrAncestorWithData<D>();
    final dataProvider = node?.dataProvider();
    if (dataProvider != null) {
      if (dataProvider is ObservableData<D>) {
        return (dataProvider as ObservableData<D>).dataStream;
      } else {
        Object data = dataProvider.data;
        if (data is D) {
          // Node does not support observable data, but it does provide a single value of
          // the right type, so adapt that value to a data stream.
          return DelegateObservableData.single(data).dataStream;
        }
      }
      throw StateError(
          'Data for state ${node.key} of type ${data.runtimeType} does not match requested type '
          '${TypeLiteral<D>().type}.');
    } else if (isTypeOf<Object, D>()) {
      // Handle case where state has no data, and requested type is a generic object. We don't want
      // to return the raw state this case, so just return null
      return null;
    } else if (node?.state() is D) {
      return !isTypeOf<D, TreeState>() && !isTypeOf<TreeState, D>()
          // In cases where state variables are just instance fields in the TreeState, and the
          // state implements the requested type, just return the state directly. This allows apps
          // to read the state data without having to use DataTreeState.
          // Note that we check if D is a tree state, and throw if it is. The idea here is that it
          // is risky to directy return a state to outside of the statemachine, since then external
          // code could call onenter/onexit and potentially violate invariants. (although external
          // code can simply do the cast themselves and work around this)
          ? DelegateObservableData.single(node.state() as D).dataStream
          : throw StateError('Requested data type ${TypeLiteral<D>().type} cannot be a '
              '${TypeLiteral<TreeState>().type} or Object or dynamic.');
    }
    return null;
  }

  DataProvider<D> selfOrAncestorDataProvider<D>([StateKey key]) {
    final node = key != null ? selfOrAncestorWithKey(key) : selfOrAncestorWithData<D>();
    final dataProvider = node?.dataProvider();
    if (dataProvider != null) {
      if (dataProvider is DataProvider<D>) {
        return dataProvider;
      }
      throw StateError(
          'Data for state ${node.key} of type ${data.runtimeType} does not match requested type '
          '${TypeLiteral<D>().type}.');
    }
    return null;
  }
}

class NodePath {
  final TreeNode from;
  final TreeNode to;
  final TreeNode lca;
  final Iterable<TreeNode> path;
  final Iterable<TreeNode> exiting;
  final Iterable<TreeNode> entering;

  NodePath._(this.from, this.to, this.lca, this.path, this.exiting, this.entering);

  factory NodePath(TreeNode from, TreeNode to, {bool reenterAncestor: false}) {
    final lca = from.lcaWith(to);
    final reenteringAncestor = reenterAncestor && lca == to;
    final reentryNode = reenteringAncestor ? [to] : const <TreeNode>[];
    final exiting =
        from.selfAndAncestors().takeWhile((n) => n != lca).followedBy(reentryNode).toList();
    final entering = reenteringAncestor
        ? reentryNode
        : to.selfAndAncestors().takeWhile((n) => n != lca).toList().reversed.toList();
    final path = exiting.followedBy(entering);
    return NodePath._(from, to, lca, path, exiting, entering);
  }

  factory NodePath.reenter(TreeNode node, TreeNode from) {
    final lca = node.lcaWith(from);
    assert(lca.key == from.key);
    final exiting = node.selfAndAncestors().takeWhile((n) => n != lca).toList();
    final entering = exiting.reversed.toList();
    final path = exiting.followedBy(entering);
    return NodePath._(node, node, lca, path, exiting, entering);
  }

  factory NodePath.enterFromRoot(TreeNode root, TreeNode to) {
    assert(root.isRoot);
    final exiting = <TreeNode>[];
    final entering = to.selfAndAncestors().toList().reversed.toList();
    final path = exiting.followedBy(entering);
    return NodePath._(root, to, null, path, exiting, entering);
  }
}
