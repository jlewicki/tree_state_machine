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
    if (key == stateKey) {
      return true;
    }
    if (parent != null) {
      return parent.isInState(stateKey);
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
