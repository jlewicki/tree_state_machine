import 'dart:async';

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

  factory TreeStateMachine.forRoot(TreeNode rootState) {
    if (rootState == null) throw ArgumentError.notNull('rootState');
    return TreeStateMachine._(rootState, StreamController());
  }

  factory TreeStateMachine.forLeaves(List<TreeNode> leafStates) {
    if (leafStates == null) throw ArgumentError.notNull('leafStates');
    var root = TreeNode(TreeState(), null);
    root.children = List.unmodifiable(leafStates);
    return TreeStateMachine._(root, StreamController());
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

class NodeContext {
  TreeNode parentNode;
  NodeContext(this.parentNode) {}
}

TreeNode root(TreeState state, List<NodeBuilder> childNodes) {
  var root = TreeNode(state, null);
  root.children = childNodes.map((childBuilder) => childBuilder(NodeContext(root)));
  return root;
}

typedef TreeNode NodeBuilder(NodeContext parentNode);
NodeBuilder leaf(TreeState state) => (ctx) => TreeNode(state, ctx.parentNode);
NodeBuilder interior({TreeState state, List<NodeBuilder> childNodes}) {
  return (ctx) {
    var interior = TreeNode(state, ctx.parentNode);
    interior.children = childNodes.map((childBuilder) => childBuilder(NodeContext(interior)));
    return interior;
  };
}

var exampleLeaf = leaf(TreeState());
var exampleInterior = interior(
  state: TreeState(),
  childNodes: [
    interior(
      state: TreeState(),
      childNodes: [
        leaf(TreeState()),
        leaf(TreeState()),
      ],
    ),
  ],
);
