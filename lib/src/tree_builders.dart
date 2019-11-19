import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class TreeNode {
  TreeState state;
  TreeNode parent;
  Iterable<TreeNode> children = [];
  TreeNode(this.state, this.parent) {}
}

class BuildContext {
  TreeNode parentNode;
  BuildContext(this.parentNode) {}
  BuildContext childContext(TreeNode newParentNode) {
    // TODO: copy other values to new context as they are introduced
    return BuildContext(newParentNode);
  }
}

abstract class BuildNode {
  TreeNode call(BuildContext ctx);
}

abstract class BuildChildNode extends BuildNode {}

class BuildRoot implements BuildNode {
  final TreeState state;
  final Iterable<BuildChildNode> children;

  BuildRoot({this.state, @required this.children}) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0) throw ArgumentError.value(children, 'children', 'Must have at least one item');
  }

  TreeNode call(BuildContext ctx) {
    var root = TreeNode(state, null);
    var childContext = ctx.childContext(root);
    root.children = children.map((childBuilder) => childBuilder(childContext));
    return root;
  }
}

class BuildInterior implements BuildChildNode {
  final TreeState state;
  final Iterable<BuildChildNode> children;

  BuildInterior({this.state, @required this.children}) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0) throw ArgumentError.value(children, 'children', 'Must have at least one item');
  }

  TreeNode call(BuildContext ctx) {
    var interior = TreeNode(state, ctx.parentNode);
    var childContext = ctx.childContext(interior);
    interior.children = children.map((childBuilder) => childBuilder(childContext));
    return interior;
  }
}

class BuildLeaf implements BuildChildNode {
  TreeState _state;

  BuildLeaf(this._state) {}

  TreeNode call(BuildContext ctx) {
    return TreeNode(_state, ctx.parentNode);
  }
}
