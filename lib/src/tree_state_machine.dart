import 'dart:async';

import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class CurrentState {
  sendMessage(Object message) {}
}

class Transition {}

class TreeStateMachine {
  final TreeNode _rootNode;
  final Map<StateKey, TreeNode> _nodeMap;
  final StreamController<Transition> _transitions;
  Stream<Transition> _transitionsStream;
  bool _isStarted = false;
  CurrentState _currentState;

  TreeStateMachine._(this._rootNode, this._nodeMap, this._transitions) {
    _transitionsStream = _transitions.stream.asBroadcastStream();
  }

  factory TreeStateMachine.forRoot(BuildRoot buildRoot) {
    if (buildRoot == null) throw ArgumentError.notNull('buildRoot');
    var buildCtx = BuildContext(null);
    var rootNode = buildRoot(buildCtx);
    return TreeStateMachine._(rootNode, buildCtx.nodes, StreamController());
  }

  factory TreeStateMachine.forLeaves(Iterable<BuildLeaf> buildLeaves) {
    if (buildLeaves == null) throw ArgumentError.notNull('buildLeaves');
    var rootBuilder = BuildRoot(state: () => _RootState(), children: buildLeaves);
    var buildCtx = BuildContext(null);
    var rootNode = rootBuilder(buildCtx);
    return TreeStateMachine._(rootNode, buildCtx.nodes, StreamController());
  }

  bool get isStarted => _isStarted;
  CurrentState get currentState => _currentState;
  Stream<Transition> get transitions => _transitionsStream;

  void start([StateKey initialStateKey]) {
    if (initialStateKey == null) throw ArgumentError.notNull('initialStateKey');
    if (_isStarted) throw StateError('This TreeStateMachine has already been started.');

    var initialNode = initialStateKey != null ? _nodeMap[initialStateKey] : _rootNode;
    if (initialNode == null) {
      throw ArgumentError.value(
          initialStateKey, 'initalStateKey', 'This TreeStateMachine does to contain the specified initial state.');
    }

    _isStarted = true;
  }
}

// Core state machine operations
class _Machine {
  final TreeNode rootNode;
  final Map<StateKey, TreeNode> nodes;
  _Machine(this.rootNode, this.nodes);

  Future<void> enterInitialState(TreeNode initialNode) async {
    // Figure out which states to enter to reach the initial state
    var entryPath = initialNode.ancestors().toList().reversed;
    for (var node in entryPath) {
      //node.handler().onEnter(ctx)
    }
  }
}

// Root state for wrapping 'flat' leaf states.
class _RootState extends EmptyTreeState {}
