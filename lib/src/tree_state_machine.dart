import 'dart:async';
import 'dart:convert';

import 'package:rxdart/rxdart.dart';
import 'package:tree_state_machine/src/helpers.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

import 'data_provider.dart';
import 'lifecycle.dart';
import 'tree_builders.dart';
import 'tree_state.dart';
import 'tree_state_machine_impl.dart';
import 'utility.dart';

/// A state machine that manages transitions among [TreeState]s that are arranged hierarchically
/// into a tree.
///
/// A [TreeStateMachine] is constructed with a [RootNodeBuilder] that will create the particular
/// tree of states that the state machine manages. After the state machine is constructed, calling
/// [start] (asynchronously) enters the initial state for the tree. Once the machine is started,
/// [currentState] returns information about the current state of the tree. Additionally,
/// [CurrentState.sendMessage] can be used to send messages to the state for processing, which may
/// result in a transition to a new state.
///
/// [TreeStateMachine] provides several event streams that may be used to observe how messages sent
/// to the machine are processed, and what state transitions occur.
///  * [processedMessages] yields an event for every message that is processed by the tree, whether
///    or not the message was handled successfully, and whether or not a transition occurred as a
///    result of the message.
///  * [handledMessages] is a convenience stream that yield an event when only when a message is
///    successfully handled.
///  * [transitions] yields an event each time a transition between states occurs.
///
/// ## Error Handling
///
/// Errors may occur when as state processes a message. This can happen in the [TreeState.onMessage]
/// handler while the state is processing the message, or it can happen during a state transition
/// in the [TreeState.onExit] handler of one of the states that is being exited, or in the
/// [TreeState.onEnter] handler of one of the states that is being entered.
///
/// In either case the state machine catches the error internally, converts it to a [FailedMessage],
/// and yields it from he future returned from [CurrentState.sendMessage]. The [FailedMessage] is
/// also emitted on he [failedMessages] stream.
///
/// See also:
///
///  * [UML State Machines](https://en.wikipedia.org/wiki/UML_state_machine), for background
///    information on UML (hierarchical) state machines.
///  * [State Machine Diagrams](https://www.uml-diagrams.org/state-machine-diagrams.html), for
///    further description of UML state machine diagrams.
class TreeStateMachine {
  final Machine _machine;
  final Lifecycle _lifecycle = Lifecycle();
  final StreamController<Transition> _transitions = StreamController.broadcast();
  final StreamController<MessageProcessed> _processedMessages = StreamController.broadcast();
  final StreamController<_QueuedMessage> _messageQueue = StreamController.broadcast();
  CurrentState _currentState;

  TreeStateMachine._(this._machine) {
    _messageQueue.stream.listen(_onMessage);
  }

  factory TreeStateMachine.forRoot(RootNodeBuilder buildRoot) {
    ArgumentError.checkNotNull(buildRoot, 'buildRoot');

    // This is twisty, since we have an indirect circular dependency between
    // CurrentLeafObservableData and TreeStateMachine
    TreeStateMachine treeMachine;
    final currentLeafData = CurrentLeafObservableData(Lazy(() => treeMachine));
    final buildCtx = TreeBuildContext(currentLeafData);
    final rootNode = buildRoot(buildCtx);
    final machine = Machine(rootNode, buildCtx.nodes);

    return treeMachine = TreeStateMachine._(machine);
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

  /// Returns `true` if the future returned by [start] has completed..
  bool get isStarted => _lifecycle.isStarted;

  /// Returns `true` if the state machine has ended.
  ///
  /// A state machine ends when a final state is entered. This may have occurred because transition
  /// to a final state has occurred as result of processing a message, or because [stop] was called.
  bool get isEnded => _machine.currentNode?.isFinal ?? false;

  /// Returns `true` if [dispose] has been called.
  bool get isDisposed => _lifecycle.isDisposed;

  /// The current state of the state machine.
  ///
  /// This will return `null` if [start] has not been called.
  CurrentState get currentState => _currentState;

  /// A broadcast stream of [Transition] events.
  ///
  /// A [Transition] is emitted on this stream when a state transition occurs within the state
  /// machine.
  Stream<Transition> get transitions => _transitions.stream;

  /// A broadcast stream of [MessageProcessed] events.
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

  /// A broadcast stream of [HandledMessage] events.
  ///
  /// A [HandledMessage] is raised on this stream when a message was successfully handled a state
  /// within the state machine.
  ///
  /// Note that the [HandledMessage] is also raised on the [processedMessages] stream.
  Stream<HandledMessage> get handledMessages =>
      Stream.castFrom(processedMessages.where((mp) => mp is HandledMessage));

  /// A broadcast stream of [FailedMessage] events.
  ///
  /// A [FailedMessage] is raised on this stream when an error was thrown from one of a states
  /// handler functions while a message was being handled or during a state transition.
  ///
  /// Note that the [FailedMessage] is also raised on the [processedMessages] stream.
  Stream<FailedMessage> get failedMessages =>
      Stream.castFrom(processedMessages.where((mp) => mp is FailedMessage));

  /// Starts the state machine, transitioning the current state to the initial state of the state
  /// tree.
  ///
  /// [initialStateKey] may be used to indicate the initial state. If provided, the state machine
  /// will transition from the root state to this state. If the initial state is a leaf state, that
  /// will be the current state when the retured future completes. Otherwise, the state machine will
  /// follow the initial child path for the initial state, until a leaf node is reached. This leaf
  /// becomes the current state when the retured future completes.
  ///
  /// If no initial state is specifed, the state machine will follow the initial child path starting
  /// from the root until a leaf node is reached.
  ///
  /// It is safe to call [start] when the state machine is already started. It is also safe to call
  /// [start] if the state machine has been stopped, in which case the state machine will be
  /// restarted, and will re-enter the initial state.
  Future start([StateKey initialStateKey]) {
    return _lifecycle.start(() async {
      final transition = await _machine.enterInitialState(initialStateKey);
      _currentState = CurrentState._(this);
      _transitions.add(transition);
      return transition;
    });
  }

  /// Stops the state machine.
  ///
  /// Stopping the state machine will cause a transition to the [StoppedTreeState]. This transition
  /// is irrevokable, and the message handler of the current leaf state will not be called.
  ///
  /// When the returned future completes, the state machine will be in a final state, and [isEnded]
  /// will return true.
  ///
  /// It is safe to call this method when [isEnded] is `true`.
  Future stop() {
    return _lifecycle.stop(() => _processMessage(stopMessage));
  }

  /// Disposes the state machine.
  ///
  /// Disposing the state machine completes the all of its streams, and will permanently mark it as
  /// disposed and unusable. Any future calls to methods that update the state machine will throw a
  /// [DisposedError].
  ///
  /// It is safe to call this method more than once.
  void dispose() {
    _lifecycle.dispose(() {
      _transitions.close();
      _processedMessages.close();
      _messageQueue.close();
      for (var node in _machine.nodes.values) {
        node.dispose();
      }
    });
  }

  /// Writes the active state data of the state machine to the specified sink.
  ///
  /// Saving the active state data allows the state of running state machine to be written to
  /// external storage. This state can be reloaded at a later time, potentially in a seperate
  /// application session, into the state machine using [loadFrom].
  ///
  /// Only information about the active states (the current leaf state and its ancestors) is saved.
  /// This means that when restoring, the state machine on which [loadFrom] is called must be
  /// constructed with the same tree definition as this state machine.
  ///
  /// The state machine must be started before this method is called, otherwise a [StateError] will
  /// be thrown.
  Future saveTo(StreamSink<List<int>> sink) {
    ArgumentError.checkNotNull(sink, 'sink');
    _lifecycle.throwIfDisposed();
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

  /// Initializes the active state data of the state machhine by reading the specified stream.
  ///
  /// The data contained in [stream] should have been generated by a previous call to [saveTo] on
  /// a state machine that is was constructed with the same tree definition as this machine.
  ///
  /// Note that this method can only be called on a state machine that has not been started. When
  /// the returned future completes, the state machine will have been started, with the current state
  /// matching the current state recorded in the stream.
  Future loadFrom(Stream<List<int>> stream) async {
    ArgumentError.checkNotNull(stream, 'stream');
    _lifecycle.throwIfDisposed();
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
    if (objectList[0] is! Map<String, dynamic>) {
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
      return treeNode ??
          (throw StateError('State machine does not contain state with key ${es.key}'));
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
    await start(activeNodes[0].key);

    // Restore encoded data into states in the tree
    for (var i = 0; i < activeNodes.length; ++i) {
      final es = encodableTree.states[i];
      final node = activeNodes[i];
      if (es.encodedData != null && node.dataProvider != null) {
        node.dataProvider.decodeInto(es.encodedData);
      }
    }
  }

  void _onMessage(_QueuedMessage queuedMessage) async {
    MessageProcessed result;
    Transition transition;
    final receivingState = _machine.currentNode.key;

    void raiseEvents(MessageProcessed result, [Transition transition]) {
      _processedMessages.add(result);
      if (transition != null) {
        _transitions.add(transition);
      }
    }

    try {
      result = await _machine.processMessage(queuedMessage.message);
      transition = result is HandledMessage ? result.transition : null;
      raiseEvents(result, transition);
    } catch (ex, stack) {
      result = FailedMessage(queuedMessage.message, receivingState, ex, stack);
      raiseEvents(result);
    }

    queuedMessage.completer.complete(result);
  }

  Future<MessageProcessed> _processMessage(Object message) async {
    _lifecycle.throwIfDisposed();
    // Add the message to the stream processor, which includes a buffering mechanism. That ensures
    // messages will be processed in-order, when messages are sent to the state machine without
    // waiting for earlier messages to be procesed.
    final completer = Completer<MessageProcessed>();
    _messageQueue.add(_QueuedMessage(message, completer));
    return completer.future;
  }
}

/// Describes the current leaf state of a [TreeStateMachine].
class CurrentState {
  final TreeStateMachine _treeStateMachine;
  CurrentState._(this._treeStateMachine);

  /// The [StateKey] identifying the current leaf state.
  StateKey get key => _treeStateMachine._machine.currentNode.key;

  /// The data associated with the state that is currently handling the message.
  ///
  /// Returns `null` if the handling state does not have an associated data provider.
  D data<D>() {
    return dataStream<D>(key)?.value;
  }

  /// The data stream of the specified type for an active state.
  ///
  /// If [key] is provided, the data stream for the ancestor state with the specified key will be
  /// returned. Otherwise, the data stream of the closest ancestor state that matches the specified
  /// type is returned.
  ///
  /// If stata data can be resolved, but it does not support streaming, a single value stream with
  /// the current state data is returned.
  ValueStream<D> dataStream<D>([StateKey key]) {
    return _treeStateMachine._machine.currentNode.dataStream<D>(key);
  }

  /// Returns `true` if the specified state is an active state in the state machine.
  ///
  /// The current leaf state, and all of its ancestor states, are considered active states.
  bool isActiveState(StateKey key) {
    ArgumentError.checkNotNull(key, 'key');
    return _treeStateMachine._machine.currentNode.isActive(key);
  }

  /// The  [StateKey]s identifying the states that are currently active in the state machine.
  ///
  /// The current leaf state is first in the list, followed by its ancestor states, and ending at
  /// the root state.
  List<StateKey> get activeStates =>
      _treeStateMachine._machine.currentNode.selfAndAncestors().map((n) => n.key).toList();

  /// Sends the specified message to the current leaf state for processing.
  ///
  /// Messages are buffered and processed in-order, so it is safe to call [sendMessage] multiple
  /// times without waiting for the futures returned by earlier calls to complete.
  ///
  /// Returns a future that yields a [MessageProcessed] describing how the message was processed,
  /// and any state transition that occured.
  Future<MessageProcessed> sendMessage(Object message) {
    ArgumentError.checkNotNull(message, 'message');
    return _treeStateMachine._processMessage(message);
  }
}

// Helper class pairing a message, and the completer that will signal the message was processed.
class _QueuedMessage {
  final Object message;
  final Completer<MessageProcessed> completer;
  _QueuedMessage(this.message, this.completer);
}

// Root state for wrapping 'flat' list of leaf states.
class _RootState extends EmptyTreeState {}

// Serialiable data for an active state in the tree.
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

// Serializable data for the state tree.
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

/// Provides read-only access to the data of the current leaf node of the state machine.
class CurrentLeafObservableData implements ObservableData<Object> {
  final Lazy<BehaviorSubject<Object>> _lazySubject;

  CurrentLeafObservableData(Lazy<TreeStateMachine> machine)
      : _lazySubject = Lazy(() {
          var values = machine.value.transitions.switchMap((trans) {
            assert(machine.value._machine.currentNode != null);
            final dataProvider = machine.value._machine.currentNode.dataProvider;
            return dataProvider is ObservableData<Object>
                ? (dataProvider as ObservableData<Object>).dataStream
                : Stream<Object>.empty();
          });
          var initialValue = machine.value._machine.currentNode?.data<Object>();
          var subject = initialValue != null
              ? BehaviorSubject.seeded(initialValue)
              : BehaviorSubject<Object>();
          subject.addStream(values);
          return subject;
        });

  @override
  ValueStream<Object> get dataStream => _lazySubject.value;
}
