import 'dart:async';
import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

class TreeStateMachine {
  final Machine _machine;
  final StreamController<Transition> _transitions = StreamController.broadcast();
  bool _isStarted = false;
  CurrentState _currentState;

  TreeStateMachine._(this._machine);

  factory TreeStateMachine.forRoot(BuildRoot buildRoot) {
    ArgumentError.checkNotNull(buildRoot, 'buildRoot');

    final buildCtx = BuildContext(null);
    final rootNode = buildRoot(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);

    return TreeStateMachine._(machine);
  }

  factory TreeStateMachine.forLeaves(Iterable<BuildLeaf> buildLeaves, StateKey initialState) {
    ArgumentError.checkNotNull(buildLeaves, 'buildLeaves');
    ArgumentError.checkNotNull(initialState, 'initialState');
    if (buildLeaves.length < 2) {
      final msg = 'Only ${buildLeaves.length} leaf states were provided. At least 2 are reequired';
      throw ArgumentError.value(buildLeaves, 'buildLeaves', msg);
    }

    final rootBuilder = BuildRoot(
      state: (key) => _RootState(),
      children: buildLeaves,
      initialChild: (_) => initialState,
    );
    final buildCtx = BuildContext(null);
    final rootNode = rootBuilder(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);
    return TreeStateMachine._(machine);
  }

  bool get isStarted => _isStarted;
  CurrentState get currentState => _currentState;
  Stream<Transition> get transitions => _transitions.stream;

  /// Starts the state machine, transitioning the current state to the initial state of the state
  /// tree.
  ///
  /// [initialStateKey] may be used to indicate the initial state. If provided, the state machine
  /// will transition from the root state to this state. If the initial state is a leaf state, that
  /// still will be the current state when the retured future completes. Otherwise, the state
  /// machine will follow the [InitialChild] path for the initial state, until a leaf node is
  /// reached. This leaf will be then become the current state when the retured future completes
  ///
  /// If no initial state is specifed, the state machine will follow the [InitialChild] path starting
  /// from the root until a leaf node is reached.
  ///
  /// A [StateError] is thrown if [start] has already been called.
  Future<TransitionContext> start([StateKey initialStateKey]) async {
    if (_isStarted) {
      throw StateError('This TreeStateMachine has already been started.');
    }

    final transCtx = await _machine.enterInitialState(initialStateKey);
    _currentState = CurrentState(transCtx.to, (msg, key) => _machine.processMessage(msg, key));
    _transitions.add(_toTransition(transCtx));
    _isStarted = true;
    return transCtx;
  }

  Transition _toTransition(MachineTransitionContext ctx) =>
      Transition(ctx.from, ctx.to, ctx.path());
}

class CurrentState {
  final StateKey key;
  final void Function(Object msg, StateKey key) dispatch;
  CurrentState(this.key, this.dispatch) {
    ArgumentError.notNull('key');
  }
  void sendMessage(Object message) {
    dispatch(message, key);
  }
}

@immutable
class Transition {
  final StateKey from;
  final StateKey to;
  final Iterable<StateKey> path;
  Transition(this.from, this.to, this.path);
}

// Root state for wrapping 'flat' list of leaf states.
class _RootState extends EmptyTreeState {}
