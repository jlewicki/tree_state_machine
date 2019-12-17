import 'package:tree_state_machine/tree_state_helpers.dart';

import 'data_provider.dart';
import 'tree_state.dart';
import 'utility.dart';

enum NodeType { rootNode, interiorNode, leafNode, finalNode }
typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef StateCreator<T extends TreeState> = T Function(StateKey key);
typedef DataStateCreator<T extends DataTreeState<D>, D> = T Function(StateKey key);

/// A node within a state tree.
class TreeNode {
  final NodeType nodeType;
  final Lazy<TreeState> _lazyState;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;
  final DataProvider dataProvider;

  TreeNode._(
    this.nodeType,
    this.key,
    this.parent,
    this._lazyState,
    this.initialChild,
    this.dataProvider,
  );

  factory TreeNode.root(
    StateKey key,
    StateCreator createState,
    InitialChild initialChild, [
    DataProvider provider,
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
    DataProvider provider,
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
    DataProvider provider,
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
    DataProvider provider,
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

  TreeState state() => _lazyState.value;

  bool isSelfOrAncestor(StateKey stateKey) => selfOrAncestorWithKey(stateKey) != null;

  Iterable<TreeNode> selfAndAncestors() sync* {
    yield this;
    yield* ancestors();
  }

  Iterable<TreeNode> ancestors() sync* {
    var nextAncestor = parent;
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent;
    }
  }

  TreeNode selfOrAncestorWithKey(StateKey stateKey) {
    return selfAndAncestors().firstWhere((n) => n.key == stateKey, orElse: () => null);
  }

  TreeNode selfOrAncestorWithData<D>() {
    return selfAndAncestors().firstWhere(
      (n) => n.dataProvider != null && n.dataProvider is DataProvider<D>,
      orElse: () => null,
    );
  }

  TreeNode lcaWith(TreeNode other) {
    final i1 = selfAndAncestors().toList().reversed.iterator;
    final i2 = other.selfAndAncestors().toList().reversed.iterator;
    TreeNode lca;
    while (i1.moveNext() && i2.moveNext()) {
      lca = i1.current.key == i2.current.key ? i1.current : lca;
    }
    assert(lca != null, 'LCA must not be null');
    return lca;
  }

  D data<D>() => dataStream<D>(key)?.value;

  DataStream<D> dataStream<D>([StateKey key]) {
    final node = key != null ? selfOrAncestorWithKey(key) : selfOrAncestorWithData<D>();
    if (node?.dataProvider != null) {
      if (node.dataProvider is ObservableData<D>) {
        return (node.dataProvider as ObservableData<D>).dataStream;
      } else {
        Object data = node.dataProvider.data;
        if (data is D) {
          return DelegateObservableData<D>(
              getData: () => data, createStream: () => Stream.value(data)).dataStream;
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
}

class NodePath {
  final TreeNode from;
  final TreeNode to;
  final TreeNode lca;
  final Iterable<TreeNode> path;
  final Iterable<TreeNode> exiting;
  final Iterable<TreeNode> entering;

  NodePath._(this.from, this.to, this.lca, this.path, this.exiting, this.entering);

  factory NodePath(TreeNode from, TreeNode to) {
    final lca = from.lcaWith(to);
    final exiting = from.selfAndAncestors().takeWhile((n) => n != lca).toList();
    final entering = to.selfAndAncestors().takeWhile((n) => n != lca).toList().reversed.toList();
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
