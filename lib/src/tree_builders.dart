import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class TreeNode {
  TreeState state;
  TreeNode parent;
  Iterable<TreeNode> children = [];
  TreeNode(this.state, this.parent) {}
}

class BuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;

  BuildContext._(this.parentNode, this.nodes) {}
  factory BuildContext(TreeNode parentNode) => BuildContext._(parentNode, HashMap());

  BuildContext childContext(TreeNode newParentNode) => BuildContext._(newParentNode, nodes);

  void addNode(TreeNode node) => nodes[node.state.key] = node;
}

abstract class BuildNode {
  TreeNode call(BuildContext ctx);
}

/**
 * Builder for non-root nodes.
 */
abstract class BuildChildNode extends BuildNode {}

class BuildRoot implements BuildNode {
  final TreeState state;
  final Iterable<BuildChildNode> children;

  BuildRoot({this.state, @required this.children}) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0) {
      throw ArgumentError.value(children, 'children', 'Must have at least one item');
    }
  }

  TreeNode call(BuildContext ctx) {
    if (ctx.parentNode != null) {
      throw ArgumentError.value(ctx, "ctx", "Unexpected parent node for root node");
    }
    var root = TreeNode(state, null);
    var childContext = ctx.childContext(root);
    root.children = children.map((childBuilder) => childBuilder(childContext));
    ctx.addNode(root);
    return root;
  }
}

class BuildInterior implements BuildChildNode {
  final TreeState state;
  final Iterable<BuildChildNode> children;

  BuildInterior({this.state, @required this.children}) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0)
      throw ArgumentError.value(children, 'children', 'Must have at least one item');
  }

  TreeNode call(BuildContext ctx) {
    var interior = TreeNode(state, ctx.parentNode);
    var childContext = ctx.childContext(interior);
    interior.children = children.map((childBuilder) => childBuilder(childContext));
    ctx.addNode(interior);
    return interior;
  }
}

class BuildLeaf implements BuildChildNode {
  TreeState _state;

  BuildLeaf(this._state) {}

  TreeNode call(BuildContext ctx) {
    var leaf = TreeNode(_state, ctx.parentNode);
    ctx.addNode(leaf);
    return leaf;
  }
}
