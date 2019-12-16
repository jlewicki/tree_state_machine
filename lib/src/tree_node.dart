import 'package:rxdart/rxdart.dart';

import 'data_provider.dart';
import 'tree_state.dart';
import 'utility.dart';

typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef StateCreator<T extends TreeState> = T Function(StateKey key);
typedef DataStateCreator<T extends DataTreeState<D>, D> = T Function(StateKey key);

class TreeNode {
  final Lazy<TreeState> _lazyState;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;
  final DataProvider dataProvider;

  TreeNode._(
    this.key,
    this.parent,
    this._lazyState,
    this.initialChild,
    this.dataProvider,
  );

  bool get isRoot => this is RootNode;
  bool get isLeaf => this is LeafNode;
  bool get isInterior => this is InteriorNode;
  bool get isFinal => this is FinalNode;
  TreeState state() => _lazyState.value;

  bool isActive(StateKey stateKey) => selfOrAncestorWithKey(stateKey) != null;

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

  ValueStream<D> dataStream<D>([StateKey key]) {
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

abstract class ChildNode extends TreeNode {
  ChildNode._(
    StateKey key,
    TreeNode parent,
    Lazy<TreeState> lazyState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) : super._(key, parent, lazyState, initialChild, provider);
}

class RootNode extends TreeNode {
  RootNode(
    StateKey key,
    StateCreator createState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) : super._(key, null, Lazy<TreeState>(() => createState(key)), initialChild, provider);
}

class InteriorNode extends ChildNode {
  InteriorNode(
    StateKey key,
    TreeNode parent,
    StateCreator<TreeState> createState,
    InitialChild initialChild, [
    DataProvider provider,
  ]) : super._(key, parent, Lazy<TreeState>(() => createState(key)), initialChild, provider);
}

class LeafNode extends ChildNode {
  LeafNode(
    StateKey key,
    TreeNode parent,
    StateCreator createState, [
    DataProvider provider,
  ]) : super._(key, parent, Lazy<TreeState>(() => createState(key)), null, provider);
}

class FinalNode extends LeafNode {
  FinalNode(
    StateKey key,
    TreeNode parent,
    StateCreator createState, [
    DataProvider provider,
  ]) : super(key, parent, createState, provider);
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
