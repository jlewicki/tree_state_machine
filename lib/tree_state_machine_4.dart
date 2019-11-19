import 'dart:async';
import 'package:meta/meta.dart';

class CurrentState {
  sendMessage(Object message) {}
}

class Transition {}

class TreeStateMachine {
  final TreeNode _rootNode;
  final StreamController<Transition> _transitions;
  Stream<Transition> _transitionsStream;
  bool _isStarted = false;
  CurrentState _currentState;

  bool get isStarted => _isStarted;
  CurrentState get currentState => _currentState;
  Stream<Transition> get transitions => _transitionsStream;

  TreeStateMachine._(this._rootNode, this._transitions) {
    _transitionsStream = _transitions.stream.asBroadcastStream();
  }

  factory TreeStateMachine.forRoot(BuildRoot buildRoot) {
    if (buildRoot == null) throw ArgumentError.notNull('buildRoot');
    var buildCtx = BuildContext(null);
    var rootNode = buildRoot(buildCtx);
    return TreeStateMachine._(rootNode, StreamController());
  }

  factory TreeStateMachine.forLeaves(List<BuildLeaf> buildLeaves) {
    if (buildLeaves == null) throw ArgumentError.notNull('buildLeaves');
    var rootBuilder = BuildRoot(state: TreeState(), children: buildLeaves);
    var buildCtx = BuildContext(null);
    var rootNode = rootBuilder(buildCtx);
    return TreeStateMachine._(rootNode, StreamController());
  }
}

class StateTree {}

class TreeState {}

class TreeNode {
  TreeState state;
  TreeNode parent;
  List<TreeNode> children = [];
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

abstract class BuildNode2 {
  TreeNode call(BuildContext ctx);
}

abstract class BuildChildNode extends BuildNode2 {}

//
//
// Another variant
//
//
class BuildRoot {
  final TreeState state;
  final List<BuildChildNode> children;

  BuildRoot({this.state, @required this.children}) {
    if (state == null) throw ArgumentError.notNull('state');
    if (children == null) throw ArgumentError.notNull('children');
    if (children.length == 0) throw ArgumentError.value(children, 'children', 'Must have at least one item');
  }

  TreeNode call(BuildContext ctx) {
    var root = TreeNode(state, null);
    var childContext = ctx.childContext(root);
    root.children = children.map((childBuilder) => childBuilder(childContext);
    return root;
  }
}

class BuildInterior implements BuildChildNode {
  final TreeState state;
  final List<BuildChildNode> children;

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

var exampleLeaf2 = BuildLeaf(TreeState());
var exampleInterior2 = BuildInterior(
  state: TreeState(),
  children: [
    BuildInterior(
      state: TreeState(),
      children: [
        BuildLeaf(TreeState()),
        BuildLeaf(TreeState()),
      ],
    ),
  ],
);

// typedef TreeNode BuildNode(BuildContext parentNode);

// class BuildTree {
//   final BuildNode buildNode;
//   BuildTree._(this.buildNode) {}

//   TreeNode call(BuildContext ctx) {
//     return this.buildNode(ctx);
//   }
// }

// class BuildRoot extends BuildTree {
//   BuildRoot._(BuildNode buildNode) : super._(buildNode) {}

//   factory BuildRoot.node({TreeState state, List<BuildTree> children}) {
//     return BuildRoot._((ctx) {
//       var root = TreeNode(state, null);
//       root.children = children.map((childBuilder) => childBuilder(BuildContext(root)));
//       return root;
//     });
//   }
// }

// class BuildInterior extends BuildTree {
//   BuildInterior._(BuildNode buildNode) : super._(buildNode) {}

//   factory BuildInterior.node({TreeState state, List<BuildTree> children}) {
//     return BuildInterior._((ctx) {
//       var root = TreeNode(state, null);
//       root.children = children.map((childBuilder) => childBuilder(BuildContext(root)));
//       return root;
//     });
//   }
// }

// class BuildLeaf extends BuildTree {
//   BuildLeaf._(BuildNode buildNode) : super._(buildNode) {}
//   factory BuildLeaf.node(TreeState state) {
//     return BuildLeaf._((ctx) => TreeNode(state, ctx.parentNode));
//   }
// }

// var exampleLeaf = BuildLeaf.node(TreeState());
// var exampleInterior = BuildInterior.node(
//   state: TreeState(),
//   children: [
//     BuildInterior.node(
//       state: TreeState(),
//       children: [
//         BuildLeaf.node(TreeState()),
//         BuildLeaf.node(TreeState()),
//       ],
//     ),
//   ],
// );
