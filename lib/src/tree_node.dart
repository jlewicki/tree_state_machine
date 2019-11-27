import 'lazy.dart';
import 'tree_state.dart';

typedef InitialChild = StateKey Function(TransitionContext ctx);
typedef StateCreator<T extends TreeState> = T Function(StateKey key);

class TreeNode {
  final Lazy<TreeState> _lazyState;
  final StateKey key;
  final TreeNode parent;
  // Consider making this list of keys
  final List<TreeNode> children = [];
  final InitialChild initialChild;

  TreeNode._(
    this.key,
    this.parent,
    this._lazyState,
    this.initialChild,
  );

  factory TreeNode(
    StateKey key,
    StateCreator<TreeState> createState,
    TreeNode parent, [
    InitialChild entryTransition,
  ]) {
    final lazyState = Lazy<TreeState>(() => createState(key));
    return TreeNode._(key, parent, lazyState, entryTransition);
  }

  factory TreeNode.terminal(StateKey key, StateCreator<TreeState> createState, TreeNode parent) {
    final lazyState = Lazy<TreeState>(() => createState(key));
    return TerminalNode._(key, parent, lazyState);
  }

  bool get isRoot => parent == null;
  bool get isLeaf => children.isEmpty;
  bool get isInterior => !isRoot && !isLeaf;
  bool get isTerminal => this is TerminalNode;
  TreeState state() => _lazyState.value;

  bool isInState(StateKey stateKey) {
    var nextNode = this;
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

class TerminalNode extends TreeNode {
  TerminalNode._(StateKey key, TreeNode parent, Lazy<TreeState> lazyState)
      : super._(key, parent, lazyState, null);
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
