import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/lazy.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class TreeNode {
  static final List<TreeNode> _emptyNodes = List<TreeNode>.from([], growable: false);
  final Lazy<TreeState> lazyState;
  final StateKey key;
  final TreeNode parent;
  Iterable<TreeNode> children = _emptyNodes;
  TreeNode(this.key, TreeState createState(), this.parent) : lazyState = Lazy<TreeState>(createState);
}

class BuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;

  BuildContext._(this.parentNode, this.nodes) {}
  factory BuildContext(TreeNode parentNode) => BuildContext._(parentNode, HashMap());

  BuildContext childContext(TreeNode newParentNode) => BuildContext._(newParentNode, nodes);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      var msg = 'A state with key ${node.key} has alreasdy been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}

abstract class BuildNode {
  TreeNode call(BuildContext ctx);
}

/**
 * Builder for non-root nodes.
 */
abstract class BuildChildNode extends BuildNode {}

class BuildRoot<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final TreeState Function() state;
  final Iterable<BuildChildNode> children;

  BuildRoot._(this.key, this.state, this.children) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0) throw ArgumentError.value(children, 'children', 'Must have at least one item');
  }

  factory BuildRoot({T state(), Iterable<BuildChildNode> children}) {
    return BuildRoot._(StateKey.forState<T>(), state, children);
  }

  factory BuildRoot.keyed({StateKey key, T state(), Iterable<BuildChildNode> children}) {
    return BuildRoot._(key, state, children);
  }

  TreeNode call(BuildContext ctx) {
    if (ctx.parentNode != null) {
      throw ArgumentError.value(ctx, "ctx", "Unexpected parent node for root node");
    }
    var root = TreeNode(key, state, null);
    var childContext = ctx.childContext(root);
    root.children = children.map((childBuilder) => childBuilder(childContext));
    ctx.addNode(root);
    return root;
  }
}

class BuildInterior<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final T Function() state;
  final Iterable<BuildChildNode> children;

  BuildInterior._(this.key, this.state, this.children) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0) throw ArgumentError.value(children, 'children', 'Must have at least one item');
  }

  factory BuildInterior({T state(), Iterable<BuildChildNode> children}) {
    return BuildInterior._(StateKey.forState<T>(), state, children);
  }

  factory BuildInterior.keyed({StateKey key, T state(), Iterable<BuildChildNode> children}) {
    return BuildInterior._(key, state, children);
  }

  TreeNode call(BuildContext ctx) {
    var interior = TreeNode(key, state, ctx.parentNode);
    var childContext = ctx.childContext(interior);
    interior.children = children.map((childBuilder) => childBuilder(childContext));
    ctx.addNode(interior);
    return interior;
  }
}

class BuildLeaf<T extends TreeState> implements BuildChildNode {
  final StateKey key;
  final T Function() createState;

  BuildLeaf._(this.key, this.createState);

  factory BuildLeaf(T Function() createState) {
    return BuildLeaf._(StateKey.forState<T>(), createState);
  }

  factory BuildLeaf.keyed(StateKey key, TreeState Function() createState) {
    return BuildLeaf._(key, createState);
  }

  TreeNode call(BuildContext ctx) {
    var leaf = TreeNode(key, createState, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  }
}
