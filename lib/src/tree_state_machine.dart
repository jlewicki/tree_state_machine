import 'dart:async';
import 'dart:convert';
import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/utility.dart';

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

    // This is twisty, since we have indirect circular dependency between getCurrentLeafData and
    // TreeStateMachine
    TreeStateMachine treeMachine;
    Object getCurrentLeafData() {
      return treeMachine.currentState.data();
    }

    final buildCtx = BuildContext(getCurrentLeafData);
    final rootNode = buildRoot(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);

    treeMachine = TreeStateMachine._(machine);
    return treeMachine;
  }

  factory TreeStateMachine.forLeaves(Iterable<LeafNodeBuilder> buildLeaves, StateKey initialState) {
    ArgumentError.checkNotNull(buildLeaves, 'buildLeaves');
    ArgumentError.checkNotNull(initialState, 'initialState');
    if (buildLeaves.length < 2) {
      final msg = 'Only ${buildLeaves.length} leaf states were provided. At least 2 are reequired';
      throw ArgumentError.value(buildLeaves, 'buildLeaves', msg);
    }

    return TreeStateMachine.forRoot(rootBuilder(
      createState: (key) => _RootState(),
      children: buildLeaves,
      initialChild: (_) => initialState,
    ));
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

  /// Writes the active states of the state machine to the specified sink.
  ///
  /// Saving the active states allows the state of running state machine to be written to external
  /// storage. This state can be reloaded at a later time, potentially in a seperate application
  /// session, into the state machine using [loadFrom].
  ///
  /// Only information about the active states (the current leaf state and its ancestors) is saved.
  /// This means that when restoring, the state machine on which [loadFrom] is called must be
  /// constructed with the same tree definition as this state machine.
  ///
  /// The state machine must be started before this method is called, otherwise a [StateError] will
  /// be thrown.
  Future saveTo(StreamSink<List<int>> sink) {
    ArgumentError.checkNotNull(sink, 'sink');
    if (!isStarted) {
      throw StateError('This TreeStateMachine must be started before saving the tree.');
    }

    // Serialize data from active states
    final stateDataList = _currentState.activeStates.map((key) {
      final node = _machine.nodes[key];
      assert(key != null, 'active state ${key.toString()} could not be found');
      final state = node.node.state();
      return EncodableState(
        key.toString(),
        state is DataTreeState ? node.node.dataProvider.encode() : null,
        null,
      );
    }).toList();

    return Stream.fromIterable(<Object>[EncodableTree(null, stateDataList).toJson()])
        .transform(json.fuse(utf8).encoder)
        .pipe(sink);
  }

  Future loadFrom(Stream<List<int>> stream) async {
    ArgumentError.checkNotNull(stream, 'stream');
    if (isStarted) {
      throw StateError('This TreeStateMachine must not be started before loading the tree.');
    }
    final objectList = await stream.transform(json.fuse(utf8).decoder).toList();
    if (objectList.length != 1) {
      throw ArgumentError.value(
        stream,
        'stream',
        'Found ${objectList.length} items in stream. Expected 1.',
      );
    }
    if (!(objectList[0] is Map<String, dynamic>)) {
      throw ArgumentError.value(
        stream,
        'stream',
        'Found ${objectList[0].runtimeType} in stream. Expected Map<String, dynamic>.',
      );
    }

    // Find tree nodes that match the encoded data
    final nodesByStringKey = Map.fromEntries(
      _machine.nodes.entries.map((e) => MapEntry(e.key.toString(), e.value.node)),
    );
    final encodableTree = EncodableTree.fromJson(objectList[0] as Map<String, dynamic>);
    final nodesForTree = encodableTree.states.map((es) {
      final treeNode = nodesByStringKey[es.key];
      return treeNode != null
          ? treeNode
          : throw StateError('State machine does not contain state with key ${es.key}');
    }).toList();

    // Make sure that node hierarchy matches that in the encoded data
    final activeNodes = nodesForTree[0].selfAndAncestors().toList();
    final encodedActivePath = encodableTree.states.map((es) => '"${es.key}"').join(', ');
    final treeActivePath = activeNodes.map((n) => '"${n.key.toString()}"').join(', ');
    final mismatchedActivePath = StateError(
        'Active path in stream [$encodedActivePath] does not match active path in state machine [$treeActivePath]');
    if (activeNodes.length != encodableTree.states.length) {
      throw mismatchedActivePath;
    }
    for (var i = 0; i < activeNodes.length; ++i) {
      final es = encodableTree.states[i];
      final node = activeNodes[i];
      if (es.key != node.key.toString()) {
        throw mismatchedActivePath;
      }
    }

    // Start state machine so that the active nodes matches that in the encoded data.
    await this.start(activeNodes[0].key);

    // Restore encoded data into states in the tree
    for (var i = 0; i < activeNodes.length; ++i) {
      final es = encodableTree.states[i];
      final node = activeNodes[i];
      if (es.encodedData != null && node.dataProvider != null) {
        node.dataProvider.decodeInto(es.encodedData);
      }
    }
  }

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

  /// The state data for the current state, or `null` if the current state does not support data.
  D data<D>() {
    return activeData<D>(key);
  }

  D activeData<D>(StateKey key) {
    final node = _treeStateMachine._machine.currentNode.selfOrAncestor(key);
    if (node.dataProvider != null) {
      Object data = node.dataProvider.data;
      return data is D
          ? data
          : throw StateError(
              'Data for state ${node.key} of type ${data.runtimeType} does not match requested type ${TypeLiteral<D>().type}.');
    } else if (node.state() is D && !(TypeLiteral<D>().type is TreeState)) {
      // In cases where state variables are just instance fields in the TreeState, and the state implements the
      // requested type, just return the state directly. This allows apps to read the state data without having
      // to use DataTreeState
      return node.state() as D;
    }
    return null;
  }

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

@JsonSerializable()
class EncodableState {
  String key;
  Object encodedData;
  String dataVersion;
  EncodableState(this.key, this.encodedData, this.dataVersion);
  factory EncodableState.fromJson(Map<String, dynamic> json) => EncodableState(
        json['key'] as String,
        json['encodedData'],
        json['dataVersion'] as String,
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'encodedData': encodedData,
        'dataVersion': dataVersion,
      };
}

@JsonSerializable()
class EncodableTree {
  String version;
  List<EncodableState> states;
  EncodableTree(this.version, this.states);
  factory EncodableTree.fromJson(Map<String, dynamic> json) => EncodableTree(
        json['version'] as String,
        (json['states'] as List)
            ?.map(
                (Object e) => e == null ? null : EncodableState.fromJson(e as Map<String, dynamic>))
            ?.toList(),
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'states': states,
      };
}
