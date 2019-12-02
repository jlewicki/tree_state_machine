import 'utility.dart';
import 'tree_state.dart';

typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef StateCreator<T extends TreeState> = T Function(StateKey key);
typedef DataStateCreator<T extends DataTreeState<D>, D> = T Function(
    StateKey key, DataProvider<D> provider);

TaggedTreeNode<Root> rootNode(
  StateKey key,
  StateCreator<TreeState> createState,
  InitialChild initialChild,
) {
  final lazyState = Lazy<TreeState>(() => createState(key));
  return TaggedTreeNode._(key, null, lazyState, initialChild, null);
}

TaggedTreeNode<Interior> interiorNode(
  StateKey key,
  StateCreator<TreeState> createState,
  TreeNode parent,
  InitialChild initialChild,
) {
  final lazyState = Lazy<TreeState>(() => createState(key));
  return TaggedTreeNode._(key, parent, lazyState, initialChild, null);
}

TaggedTreeNode<Leaf> leafNode(
  StateKey key,
  StateCreator<TreeState> createState,
  TreeNode parent,
) {
  final lazyState = Lazy<TreeState>(() => createState(key));
  return TaggedTreeNode._(key, parent, lazyState, null, null);
}

TaggedTreeNode<Final> finalNode(
  StateKey key,
  StateCreator<TreeState> createState,
  TreeNode parent,
) {
  final lazyState = Lazy<TreeState>(() => createState(key));
  return TaggedTreeNode._(key, parent, lazyState, null, null);
}

class TreeNode {
  final Lazy<TreeState> _lazyState;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;
  final DataProvider provider;

  TreeNode._(this.key, this.parent, this._lazyState, this.initialChild, this.provider);

  bool get isRoot => this is TaggedTreeNode<Root>;
  bool get isLeaf => this is TaggedTreeNode<Leaf> || this is TaggedTreeNode<Final>;
  bool get isInterior => this is TaggedTreeNode<Interior>;
  bool get isFinal => this is TaggedTreeNode<Final>;
  TreeState state() => _lazyState.value;

  bool isActive(StateKey stateKey) {
    TreeNode nextNode = this;
    while (nextNode != null) {
      if (nextNode.key == stateKey) {
        return true;
      }
      nextNode = nextNode.parent;
    }
    return false;
  }

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
}

class TaggedTreeNode<T extends NodeType> extends TreeNode {
  TaggedTreeNode._(
    StateKey key,
    TreeNode parent,
    Lazy<TreeState> lazyState,
    InitialChild initialChild,
    DataProvider provider,
  ) : super._(key, parent, lazyState, initialChild, provider);
}

abstract class NodeType {}

abstract class Root extends NodeType {}

abstract class ChildNode extends NodeType {}

abstract class Leaf extends ChildNode {}

abstract class Final extends ChildNode {}

abstract class Interior extends ChildNode {}

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
