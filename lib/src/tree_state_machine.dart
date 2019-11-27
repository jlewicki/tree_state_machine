import 'dart:async';
import 'tree_builders.dart';
import 'tree_state.dart';
import 'tree_state_machine_impl.dart';

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

  /// Returns `true` if [start] has been called.
  bool get isStarted => _isStarted;

  /// Returns `true` if the state machine has ended.
  ///
  /// A state machine ends when a terminal state is entered.
  bool get isEnded => isStarted && _machine.currentNode.isTerminal;

  /// The current state of the state machine.
  ///
  /// This will return `null` if [start] has not been called.
  CurrentState get currentState => _currentState;

  /// Stream of [Transition] events.
  ///
  /// A [Transition] is emitted on this stream when a state transition occurs within the state
  /// machine.
  Stream<Transition> get transitions => _transitions.stream;

  /// Starts the state machine, transitioning the current state to the initial state of the state
  /// tree.
  ///
  /// [initialStateKey] may be used to indicate the initial state. If provided, the state machine
  /// will transition from the root state to this state. If the initial state is a leaf state, that
  /// still will be the current state when the retured future completes. Otherwise, the state
  /// machine will follow the initial child path for the initial state, until a leaf node is
  /// reached. This leaf will be then become the current state when the retured future completes
  ///
  /// If no initial state is specifed, the state machine will follow the initial child path starting
  /// from the root until a leaf node is reached.
  ///
  /// A [StateError] is thrown if [start] has already been called.
  Future<TransitionContext> start([StateKey initialStateKey]) async {
    if (_isStarted) {
      throw StateError('This TreeStateMachine has already been started.');
    }

    final transCtx = await _machine.enterInitialState(initialStateKey);
    _currentState = CurrentState(transCtx.end, _machine.processMessage);
    _transitions.add(transCtx.toTransition());
    _isStarted = true;
    return transCtx;
  }
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

// Root state for wrapping 'flat' list of leaf states.
class _RootState extends EmptyTreeState {}
