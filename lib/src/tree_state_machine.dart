import 'dart:async';

import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

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

  factory TreeStateMachine.forLeaves(Iterable<BuildLeaf> buildLeaves) {
    if (buildLeaves == null) throw ArgumentError.notNull('buildLeaves');
    var rootBuilder = BuildRoot(state: () => _RootState(), children: buildLeaves);
    var buildCtx = BuildContext(null);
    var rootNode = rootBuilder(buildCtx);
    return TreeStateMachine._(rootNode, StreamController());
  }
}

// Root state for wrapping 'flat' leaf states.
class _RootState extends EmptyTreeState {}
