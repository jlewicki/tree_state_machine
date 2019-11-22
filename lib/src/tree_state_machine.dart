import 'dart:async';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

class CurrentState {
  void sendMessage(Object message) {}
}

class Transition {}

class TreeStateMachine {
  final Machine _machine;
  final StreamController<Transition> _transitions;
  Stream<Transition> _transitionsStream;
  bool _isStarted = false;
  CurrentState _currentState;

  TreeStateMachine._(this._machine, this._transitions) {
    _transitionsStream = _transitions.stream.asBroadcastStream();
  }

  factory TreeStateMachine.forRoot(BuildRoot buildRoot) {
    ArgumentError.checkNotNull(buildRoot, 'buildRoot');

    final buildCtx = BuildContext(null);
    final rootNode = buildRoot(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);

    return TreeStateMachine._(machine, StreamController());
  }

  factory TreeStateMachine.forLeaves(Iterable<BuildLeaf> buildLeaves, StateKey initialState) {
    ArgumentError.checkNotNull(buildLeaves, 'buildLeaves');
    ArgumentError.checkNotNull(initialState, 'initialState');

    final rootBuilder = BuildRoot(
      state: (key) => _RootState(),
      children: buildLeaves,
      initialChild: (_) => initialState,
    );
    final buildCtx = BuildContext(null);
    final rootNode = rootBuilder(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);

    return TreeStateMachine._(machine, StreamController());
  }

  bool get isStarted => _isStarted;
  CurrentState get currentState => _currentState;
  Stream<Transition> get transitions => _transitionsStream;

  void start([StateKey initialStateKey]) {
    if (_isStarted) {
      throw StateError('This TreeStateMachine has already been started.');
    }

    _machine.enterInitialState(initialStateKey);

    _isStarted = true;
  }
}

// Root state for wrapping 'flat' leaf states.
class _RootState extends EmptyTreeState {}
