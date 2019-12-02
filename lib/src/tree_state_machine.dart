import 'dart:async';
import 'tree_builders.dart';
import 'tree_state.dart';
import 'tree_state_machine_impl.dart';

class TreeStateMachine {
  final Machine _machine;
  final StreamController<Transition> _transitions = StreamController.broadcast();
  final StreamController<MessageProcessed> _processedMessages = StreamController.broadcast();
  bool _isStarted = false;
  CurrentState _currentState;

  TreeStateMachine._(this._machine);

  factory TreeStateMachine.forRoot(RootNodeBuilder buildRoot) {
    ArgumentError.checkNotNull(buildRoot, 'buildRoot');

    final buildCtx = BuildContext(null);
    final rootNode = buildRoot(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);

    return TreeStateMachine._(machine);
  }

  factory TreeStateMachine.forLeaves(Iterable<LeafNodeBuilder> buildLeaves, StateKey initialState) {
    ArgumentError.checkNotNull(buildLeaves, 'buildLeaves');
    ArgumentError.checkNotNull(initialState, 'initialState');
    if (buildLeaves.length < 2) {
      final msg = 'Only ${buildLeaves.length} leaf states were provided. At least 2 are reequired';
      throw ArgumentError.value(buildLeaves, 'buildLeaves', msg);
    }

    final rootBuilder = buildRoot(
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
  /// A state machine ends when a final state is entered.
  bool get isEnded => isStarted && _machine.currentNode.isFinal;

  /// The current state of the state machine.
  ///
  /// This will return `null` if [start] has not been called.
  CurrentState get currentState => _currentState;

  /// Stream of [Transition] events.
  ///
  /// A [Transition] is emitted on this stream when a state transition occurs within the state
  /// machine.
  Stream<Transition> get transitions => _transitions.stream;

  /// Stream of [MessageProcessed] events.
  ///
  /// A [MessageProcessed] event is raised on this stream when a message was processed by a state
  /// within the state machine. The result of this processing may have resulted in a state
  /// transition, in which case an event will also be raised on the [transitions] stream.  When this
  /// occurs, an event on this stream is raised first.
  ///
  /// Note that the [MessageProcessed] event does not necessarily mean that the message was handled
  /// successfully; it might have been unhandled or an error might have occurred. Check the runtime
  /// type of the event to determine what occurred.
  Stream<MessageProcessed> get processedMessages => _processedMessages.stream;

  /// Stream of [HandledMessage] events.
  ///
  /// A [HandledMessage] is raised on this stream when a message was successfully handled a state
  /// within the state machine.
  ///
  /// Note that the [HandledMessage] is also raised on the [processedMessages] stream.
  Stream<HandledMessage> get handledMessages =>
      Stream.castFrom(processedMessages.where((mp) => mp is HandledMessage));

  /// Stream of [ProcessingError] events.
  ///
  /// A [ProcessingError] is raised on this stream when an error was thrown from one of a states
  /// handler functions while a message was being handled or during a state transition.
  ///
  /// Note that the [ProcessingError] is also raised on the [processedMessages] stream.
  Stream<ProcessingError> get errors =>
      Stream.castFrom(processedMessages.where((mp) => mp is ProcessingError));

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
  Future<Transition> start([StateKey initialStateKey]) async {
    if (isStarted) {
      throw StateError('This TreeStateMachine has already been started.');
    }

    final transition = await _machine.enterInitialState(initialStateKey);
    _currentState = CurrentState._(this);
    _transitions.add(transition);
    _isStarted = true;
    return transition;
  }

  // void saveTree(IOSink sink) {
  //   ArgumentError.checkNotNull(sink, 'sink');
  //   if (!isStarted) {
  //     throw StateError('This TreeStateMachine must be started before saving the tree.');
  //   }
  //   SaveContext
  // }

  Future<MessageProcessed> _processMessage(Object message) async {
    MessageProcessed result;
    Transition transition;
    final receivingState = _machine.currentNode.key;

    try {
      result = await _machine.processMessage(message);
      transition = result is HandledMessage ? result.transition : null;
    } catch (ex, stack) {
      result = ProcessingError(message, receivingState, ex, stack);
    }

    // Raise events. Note that our stream controllers are async, so that this method will complete
    // before events are visible to listeners.
    _processedMessages.add(result);
    if (transition != null) {
      _transitions.add(transition);
    }

    return result;
  }
}

/// Describes the state that is the current leaf state of a [TreeStateMachine].
class CurrentState {
  final TreeStateMachine _treeStateMachine;
  CurrentState._(this._treeStateMachine);

  /// The [StateKey] identifying the current leaf state.
  StateKey get key => _treeStateMachine._machine.currentNode.key;

  /// Returns `true` if the specified state is an active state in the state machine.
  ///
  /// The current state, and all of its ancestor states, are active states.
  bool isActiveState(StateKey key) {
    ArgumentError.checkNotNull(key, 'key');
    return _treeStateMachine._machine.currentNode.isActive(key);
  }

  /// Returns [StateKey]s identifying the states that are currently active in the state machine.
  ///
  /// The current state is first in the list, followed by its ancestor states, and ending at
  /// the root state.
  List<StateKey> get activeStates =>
      _treeStateMachine._machine.currentNode.selfAndAncestors().map((n) => n.key).toList();

  /// Sends the specified message to the current leaf state for processing.
  ///
  /// Returns a future that yields a [MessageProcessed] describing how the message was processed,
  /// and any state transition that occured.
  Future<MessageProcessed> sendMessage(Object message) {
    ArgumentError.checkNotNull(message, 'message');
    return _treeStateMachine._processMessage(message);
  }
}

// Root state for wrapping 'flat' list of leaf states.
class _RootState extends EmptyTreeState {}

// class _StateTreeData {
//   String treeVersion;
//   StateKey currentState;
//   Map<StateKey, StateData> dataByKey;
// }
