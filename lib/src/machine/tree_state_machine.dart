import 'dart:async';
import 'dart:convert';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/async.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/initial_state_data.dart';
import 'package:tree_state_machine/src/machine/machine.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/tree_builders.dart';

import 'lifecycle.dart';
import 'tree_state.dart';
import 'utility.dart';

/// A state machine that manages transitions among the states in a state tree.
///
/// A [TreeStateMachine] is constructed with a [DeclarativeStateTreeBuilder] that will create the specific
/// tree of states that the state machine manages. After the state machine is constructed, calling
/// [start] will enter the initial state for the tree, and return a [CurrentState] that serves as
/// a proxy for the current state of the state tree. [CurrentState.post] can be used to send
/// a message to the state for processing, which may result in a transition to a new state.
/// ```dart
///   var stateTreeBuilder = createTreeBuilder();
///   var stateMachine = TreeStateMachine(stateTreeBuilder);
///
///   var currentState = await stateMachine.start();
///   print('The current state is ${currentState.key}');
///
///   var messageProcessed = await currentState.post(MyMessage());
///   print('The current state after processing a message is ${currentState.key}');
/// ```
///
/// When the machine is started, the machine determines determine a path of states, starting at the
/// root and ending at a leaf state, by recursively determining the `initialChild` at each level of
/// the tree until a state with no children is reached. This path of states is called the initial
/// path, and the machine will call `onEnter` for each state along this path. When all the states
/// along the path have been entered, the state at the end of the path becomes the current state of
/// the state machine.
///
/// ## Event Streams
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
/// and yields it from he future returned from [CurrentState.post]. The [FailedMessage] is
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
  final _lifecycle = Lifecycle();
  final _transitions = StreamController<Transition>.broadcast();
  final _processedMessages = StreamController<ProcessedMessage>.broadcast();
  final _messageQueue = StreamController<_QueuedMessage>.broadcast();
  final _dataStreams = <_DataStreamKey, ValueSubject<dynamic>>{};
  final PostMessageErrorPolicy _errorPolicy;
  final Logger _log;
  CurrentState? _currentState;

  TreeStateMachine._(this._machine, this._errorPolicy, this._log, this.label) {
    _messageQueue.stream.listen(_onMessage);

    // Listen to states that are entered
    _transitions.stream
        .expand((t) => _mapStateDataValues(t.entryPath))
        .listen((sdv) {
      var keyByStateKey = (sdv.stateKey, sdv.dataValue.dataType);
      var keyByDataType = (null, sdv.dataValue.dataType);
      var dataStream =
          _dataStreams[keyByStateKey] ?? _dataStreams[keyByDataType];
      if (dataStream != null) {
        dataStream.addStream(sdv.dataValue);
      }
    });
  }

  /// Constructs a state machine for the state tree defined by [treeBuilder].
  ///
  /// If [logName] is provided, it will be used as a suffix in the name of the [Logger] that this
  /// state machine logs with. This can help disambiguate log messages if more than one state
  /// machine is running at the same time.
  ///
  /// A [label] can be optionally be provided for the this machine. This will not used by the state
  /// machine, but may be useful for diagnostic purposes.
  ///
  /// [postMessageErrorPolicy] can be used to control how the future returned by [CurrentState.post]
  /// behaves when an error occurs while processing the posted message.
  ///
  /// A [buildContext] can be provided in place of the default context. This is typically not needed,
  /// but may be useful in advanced scenarios requiring access to the state tree when as it is built.
  factory TreeStateMachine(
    StateTreeBuilder treeBuilder, {
    String? label,
    String? logName,
    PostMessageErrorPolicy postMessageErrorPolicy =
        PostMessageErrorPolicy.convertToFailedMessage,
    TreeBuildContext? buildContext,
  }) {
    logName = logName ?? label ?? treeBuilder.logName;
    label = label ?? treeBuilder.label;
    TreeStateMachine? treeMachine;
    var buildCtx = buildContext ?? TreeBuildContext();
    var rootNode = treeBuilder.build(buildCtx);
    var machine = Machine(
      rootNode,
      buildCtx.nodes,
      (message) => treeMachine!._queueMessage(message),
      logName: logName,
    );
    var log = Logger(
      'tree_state_machine.TreeStateMachine${logName != null ? '.$logName' : ''}',
    );
    return treeMachine =
        TreeStateMachine._(machine, postMessageErrorPolicy, log, label);
  }

  /// An optional descriptive label for this state machine, for diagnostic purposes.
  final String? label;

  /// The current state of this state machine.
  ///
  /// Returns `null` if the state machine has not been started, or if it is disposed.
  CurrentState? get currentState => _currentState;

  /// Returns `true` if the state machine has ended.
  ///
  /// A state machine is done when a final state is entered. This may have occurred because transition
  /// to a final state has occurred as result of processing a message, or because [stop] was called.
  bool get isDone => switch (_machine.currentLeaf) {
        LeafTreeNode(isFinalState: var f) when f => true,
        _ => false
      };

  /// A broadcast [ValueStream] of [LifecycleState] events.
  ///
  /// An event is emitted on this stream as the state machine moves through its lifecycle. For
  /// example, [LifecycleState.started] will be emitted when [start] is called, and the returned
  /// future completes.
  ValueStream<LifecycleState> get lifecycle => _lifecycle.states;

  /// A broadcast stream of [Transition] events.
  ///
  /// A [Transition] is emitted on this stream when a state transition occurs within the state
  /// machine.
  Stream<Transition> get transitions => _transitions.stream;

  /// A broadcast stream of [ProcessedMessage] events.
  ///
  /// A [ProcessedMessage] event is raised on this stream when a message was processed by a state
  /// within the state machine. The result of this processing may have resulted in a state
  /// transition, in which case an event will also be raised on the [transitions] stream.  When this
  /// occurs, an event on this stream is raised first.
  ///
  /// Note that the [ProcessedMessage] event does not necessarily mean that the message was handled
  /// successfully; it might have been unhandled or an error might have occurred. Check the runtime
  /// type of the event to determine what occurred.
  Stream<ProcessedMessage> get processedMessages => _processedMessages.stream;

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

  /// The [TreeNodeInfo] of the root node of this state machine.
  ///
  /// Each node in the state tree is accessible from this node and its [TreeNodeInfo.getChildren].
  TreeNodeInfo get rootNode => _machine.rootNode.treeNode;

  /// Starts the state machine, transitioning the current state to the initial state of the state
  /// tree. Returns a [CurrentState] that can be used to send messages for processing.
  ///
  /// [at] may be used to indicate the initial state. If provided, the state machine
  /// will transition from the root state to this state. If the initial state is a leaf state, that
  /// will be the current state when the returned future completes. Otherwise, the state machine
  /// will follow the initial child path for the initial state, until a leaf state is reached. This
  /// leaf becomes the current state when the returned future completes.
  ///
  /// If no initial state is specified, the state machine will follow the initial child path
  /// starting from the root until a leaf state is reached.
  ///
  /// [withData] may be used to specify initial state data values for any data states that are
  /// entered while starting the state machine. It is not necessary for the [withData] function to
  /// specify a data value for every data state that is entered. If it does not contain a value for
  /// a data state, the [InitialData] associated with that data state will used instead.
  ///
  /// Note that while [withData] can be used to start or restore the state machine with a specific
  /// set of values, it is of course possible that these values may be ones that would never be
  /// produced by the state machine itself when started without [withData], potentially breaking
  /// invariants expected by the state tree. As a result, [withData] is intended primarily for
  /// development and testing purposes, and care should be taken when using it.
  ///
  /// It is safe to call [start] when the state machine is already started. It is also safe to call
  /// [start] if the state machine has been stopped, in which case the state machine will be
  /// restarted, and will re-enter the initial state.
  Future<CurrentState> start({
    StateKey? at,
    BuildInitialData? withData,
    Object? initialPayload,
  }) async {
    await _lifecycle.start(() async {
      var initData = withData != null ? InitialStateData(withData) : null;
      final transition =
          await _machine.enterInitialState(at, initData, initialPayload);
      _currentState = CurrentState._(this);
      _transitions.add(transition);
      return transition;
    });
    assert(_currentState != null);
    return _currentState!;
  }

  /// Stops the state machine.
  ///
  /// Stopping the state machine will cause a transition to a final state identified by
  /// [stoppedStateKey]. This transition is irrevocable, and the message handler of the current leaf
  /// state will not be called before the transition occurs.
  ///
  /// When the returned future completes, the the [CurrentState.key] will be [stoppedStateKey], and
  /// [isDone] will return true.
  ///
  /// Because the state machine could potentially be restarted, stopping the state machine does not
  /// complete state machine streams such as [transitions]. If the state machine will never be
  /// restarted, [dispose] can be used to complete the streams, or any subscriptions may explicitly
  /// be canceled.
  ///
  /// It is safe to call this method if [isDone] is already `true`.
  Future<void> stop() {
    return _lifecycle.stop(() => _queueMessage(stopMessage));
  }

  /// Disposes the state machine.
  ///
  /// Disposing the state machine completes the all of its streams, and will permanently mark it as
  /// disposed and unusable. Any future calls to methods that update the state machine will throw a
  /// [DisposedError].
  ///
  /// Additionally, the [DataValue] in each data state will be marked as complete. Note however that
  /// listeners to the [DataValue] will not be notified of completion until the next microtask.
  ///
  /// It is safe to call this method more than once.
  void dispose() {
    _lifecycle.dispose(() {
      _transitions.close();
      _processedMessages.close();
      _messageQueue.close();
      _currentState = null;
      for (var node in _machine.nodes.values) {
        node.dispose();
      }
      // We just disposed the nodes, which means the data values for any data states were closed.
      // However the Done notifications for those data values are sent asynchronously in a microtask,
      // so we cant close data streams (which are listening to the data value streams) until those
      // Done notifications are flushed. So use a timer to wait for this (since timers run on the
      // event loop, which is processed at lower priority than microtasks).
      // FUTURE: is there a better way of handling this?
      Timer.run(() {
        for (var dataStream in _dataStreams.values) {
          dataStream.close();
        }
      });
    });
  }

  /// Gets the data stream for a data tree state with state data of type [D].
  ///
  /// A data tree state has an associated data value of type [D]. As messages are processed by the
  /// state, it may update its data value. Each time the value changes, the new value is published
  /// to this stream.
  ///
  /// Note that this stream does not complete until this state machine is disposed. The stream will
  /// continue to emit values if the data tree state is exited, and then re-entered.
  ValueStream<D> dataStream<D>([DataStateKey<D>? key]) {
    _lifecycle.throwIfDisposed();

    _DataStreamKey streamKey = (key, D);
    var dataStream = _dataStreams[streamKey];
    if (dataStream == null) {
      // We don't have as datastream yet for this data type/key, so create a new one
      dataStream = ValueSubject<D>();
      _dataStreams[streamKey] = dataStream;
      if (_currentState != null) {
        for (var sdv in _mapStateDataValues(_currentState!.activeStates)) {
          // If the requested data type/key match one of the current active states, pipe the
          // notifications from the active state through the data stream.
          if (sdv.stateKey == key || sdv.dataValue.dataType == D) {
            dataStream.addStream(sdv.dataValue as ValueStream<D>);
          }
        }
      }
    }
    return dataStream as ValueStream<D>;
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
  Future<void> saveTo(StreamSink<List<int>> sink) {
    ArgumentError.checkNotNull(sink, 'sink');
    _lifecycle.throwIfDisposed();
    if (!lifecycle.isStarted) {
      throw StateError(
          'This TreeStateMachine must be started before saving the tree.');
    }

    // Serialize data from active states
    var version = '1.0';
    var stateDataList = _currentState!.activeStates.map((key) {
      var node = _machine.nodes[key];
      assert(node != null, 'active state ${key.toString()} could not be found');
      var dataValue = node!.treeNode.data;
      var stateData = dataValue?.value;
      var codec = node.treeNode.dataCodec;
      stateData = stateData != null && codec != null
          ? codec.serialize(stateData)
          : stateData;
      return EncodableState(key.toString(), stateData, version);
    }).toList();

    var converter = json.fuse(utf8).encoder;
    List<Object?> items = [EncodableTree(version, stateDataList)];
    return Stream.fromIterable(items).transform(converter).pipe(sink);
  }

  /// Initializes the active state data of the state machine by reading the specified stream.
  ///
  /// The data contained in [stream] should have been generated by a previous call to [saveTo] on
  /// a state machine that is was constructed with the same tree definition as this machine.
  ///
  /// Note that this method can only be called on a state machine that has not been started. When
  /// the returned future completes, the state machine will have been started, with the current state
  /// matching the current state recorded in the stream.
  Future<CurrentState> loadFrom(Stream<List<int>> stream) async {
    _lifecycle.throwIfDisposed();
    if (lifecycle.isStarted) {
      throw StateError(
          'This TreeStateMachine must not be started before loading the tree.');
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
      _machine.nodes.entries
          .map((e) => MapEntry(e.key.toString(), e.value.treeNode)),
    );
    final encodableTree =
        EncodableTree.fromJson(objectList[0] as Map<String, dynamic>);
    final nodesForTree = encodableTree.states.map((es) {
      final treeNode = nodesByStringKey[es.key];
      return treeNode ??
          (throw StateError(
              'State machine does not contain state with key ${es.key}'));
    }).toList();

    // Make sure that node hierarchy matches that in the encoded data
    final activeNodes = nodesForTree[0].selfAndAncestors().toList();
    final encodedActivePath =
        encodableTree.states.map((es) => '"${es.key}"').join(', ');
    final treeActivePath =
        activeNodes.map((n) => '"${n.key.toString()}"').join(', ');
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
    return start(
      at: activeNodes[0].key,
      withData: (b) {
        for (var i = 0; i < activeNodes.length; ++i) {
          final es = encodableTree.states[i];
          final node = activeNodes[i];
          // It's not useful to have a DataTreeState<void>, but it is not prohibited,
          // so skip those states (there is no data to set)
          if (node.state is DataTreeState &&
              node.state is! DataTreeState<void>) {
            if (node.dataCodec == null) {
              throw StateError(
                  'Unable to deserialize state data because a serializer has not been '
                  'specified for state ${node.key}');
            }

            var stateData =
                (node.dataCodec!).deserialize(es.encodedStateData) as Object;
            b.initialData(node.key as DataStateKey, stateData);
          }
        }
      },
    );
  }

  void _onMessage(_QueuedMessage queuedMessage) async {
    ProcessedMessage result;
    final receivingState = _machine.currentLeaf!.key;

    void raiseEvents(ProcessedMessage result) {
      _processedMessages.add(result);
      if (result is HandledMessage) {
        if (result.transition != null) {
          _transitions.add(result.transition!);
        }
      }
    }

    try {
      result = await _machine.processMessage(queuedMessage.message);
      raiseEvents(result);
    } catch (ex, stack) {
      _log.warning(
          "Error occurred when processing message '${queuedMessage.message}'",
          ex,
          stack);
      result = FailedMessage(queuedMessage.message, receivingState, ex, stack);
      raiseEvents(result);
      if (_errorPolicy == PostMessageErrorPolicy.rethrowError) {
        queuedMessage.completer.completeError(ex, stack);
        return;
      }
    }
    queuedMessage.completer.complete(result);
  }

  Future<ProcessedMessage> _queueMessage(Object message) async {
    _lifecycle.throwIfDisposed();
    // Add the message to the stream processor, which includes a buffering mechanism. That ensures
    // messages will be processed in-order, when messages are sent to the state machine without
    // waiting for earlier messages to be procesed.
    final completer = Completer<ProcessedMessage>();
    _messageQueue.add(_QueuedMessage(message, completer));
    return completer.future;
  }

  Iterable<_StateDataValue> _mapStateDataValues(Iterable<StateKey> keys) {
    return keys
        .map((key) {
          var treeNode = _machine.nodes[key]?.treeNode;
          return treeNode?.key is DataStateKey
              ? _StateDataValue(treeNode!.key as DataStateKey, treeNode.data!)
              : null;
        })
        .where((stateDataVal) => stateDataVal != null)
        .cast<_StateDataValue>();
  }
}

/// Describes how the future returned by [CurrentState.post] behaves when an error occurs while a
/// state processes the posted message.
enum PostMessageErrorPolicy {
  /// The error is caught and converted to a [FailedMessage] that is returned when the future
  /// returned by [CurrentState.post] is awaited.
  convertToFailedMessage,

  /// The error is rethrown when the future returned by [CurrentState.post] is awaited.
  rethrowError,
}

/// Describes the current leaf state of a [TreeStateMachine].
///
/// [CurrentState] provides information about the current leaf state and its ancestor states, as
/// well as the data value of any active data states. These values change over time as messages
/// are processed and state transitions occur.
///
/// Messages can be sent to the leaf state for processing using the [post] method.
class CurrentState {
  /// The state machine for this current state.
  final TreeStateMachine stateMachine;

  CurrentState._(this.stateMachine);

  // TODO: what if machine is stopped?

  /// The [StateKey] identifying the current leaf state.
  StateKey get key => stateMachine._machine.currentLeaf!.key;

  /// Returns the value stream of state data type [D] associated with an active data state.
  ///
  /// Starting with the current leaf state, each active state is visited. If a state has a state
  /// data value that matches [D], then the value stream for that state is returned. If [key] is
  /// provided, then the value is only returned if the key matches an active state.
  ///
  /// If [D] is `dynamic`, then the data for the current leaf state is returned, or `null` if the
  /// current leaf state is not a data state.
  ///
  /// If [D] is `void`, `null` is returned.
  ///
  /// The retured stream completes when the state to which it corresponds is no longer active. If a
  /// long lived stream is needed that remains valid as the state becomes inactive then active
  /// again, then [TreeStateMachine.dataStream] can be used.
  ValueStream<D>? dataStream<D>([DataStateKey<D>? key]) {
    if (isTypeOfExact<void, D>()) return null;
    var node = stateMachine._machine.currentLeaf!;
    return node.selfOrAncestorDataValue<D>(key: key);
  }

  /// Returns the state data of a given type associated with an active state.
  ///
  /// Starting with the current leaf state, each active state is visited. If a state has a state
  /// data value that matches `D`, then that data value is returned. If [key] is provided, then
  /// the value is only returned if the key matches the active state.
  ///
  /// If [D] is `dynamic`, then the data for the current leaf state is returned, or `null` if the
  /// current leaf state is not a data state.
  ///
  /// Returns `null` if a data value could not be resolved, or if `Object` is specified for `D`.
  ///
  /// ```dart
  ///   // Assume the active state hierarchy is as follows, with S5 as the
  ///   // current leaf state:
  ///   // (S5, state data C) ->
  ///   // (S4, state data C) ->
  ///   // (S3: no state data) ->
  ///   // (S2: state data B) ->
  ///   // (S1: state data A)
  ///
  ///   currentState.dataValue<A>();      // Returns data from S1
  ///   currentState.dataValue<B>();      // Returns data from S2
  ///   currentState.dataValue<C>();      // Returns data from S5
  ///   currentState.dataValue<C>(S4);    // Returns data from S4
  ///   currentState.dataValue<D>();      // Returns null
  ///   currentState.dataValue();         // Returns data from S5
  ///   currentState.dataValue<void>();   // Returns null
  /// ```
  D? dataValue<D>([DataStateKey<D>? key]) => dataStream<D>(key)?.value;

  /// Returns `true` if the specified state is an active state in the state machine.
  ///
  /// The current leaf state, and all of its ancestor states, are considered active states.
  bool isInState(StateKey key) {
    return stateMachine._machine.currentLeaf!.isSelfOrAncestor(key);
  }

  /// The [StateKey]s identifying the states that are currently active in the state machine.
  ///
  /// The current leaf state is first in the list, followed by its ancestor states, and ending at
  /// the root state.
  List<StateKey> get activeStates => stateMachine._machine.currentLeaf!
      .selfAndAncestors()
      .map((n) => n.key)
      .toList();

  /// Sends the specified message to the current leaf state for processing.
  ///
  /// Messages are buffered and processed in-order, so it is safe to call [post] multiple
  /// times without waiting for the futures returned by earlier calls to complete.
  ///
  /// Returns a future that yields a [ProcessedMessage] describing how the message was processed,
  /// and any state transition that occured.
  ///
  /// If an error occurred while processing the message, and the state machine was created with
  /// [PostMessageErrorPolicy.rethrowError], then the future will throw the error when awaited.
  /// Otherwise, the future will yield a [FailedMessage] when awaited.
  Future<ProcessedMessage> post(Object message) {
    return stateMachine._queueMessage(message);
  }
}

// Helper class pairing a message, and the completer that will signal the message was processed.
class _QueuedMessage {
  final Object message;
  final Completer<ProcessedMessage> completer;
  _QueuedMessage(this.message, this.completer);
}

// Serialiable data for an active state in the tree.
class EncodableState {
  String key;
  Object? encodedStateData;
  String dataVersion;
  EncodableState(this.key, this.encodedStateData, this.dataVersion);
  factory EncodableState.fromJson(Map<String, dynamic> json) => EncodableState(
        json['key'] as String,
        json['encodedStateData'],
        json['dataVersion'] as String,
      );
  Map<String, dynamic> toJson() => <String, dynamic>{
        'key': key,
        'encodedStateData': encodedStateData,
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
            .map((e) => e == null
                ? null
                : EncodableState.fromJson(e as Map<String, dynamic>))
            .where((e) => e != null)
            .cast<EncodableState>()
            .toList(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'version': version,
        'states': states,
      };
}

class _StateDataValue {
  final DataStateKey<dynamic> stateKey;
  final DataValue<dynamic> dataValue;
  _StateDataValue(this.stateKey, this.dataValue);
}

// Composite key for data streams.  If key is null, that means calling code requested a data string
// by state data type, omitting the key of a specific state.
typedef _DataStreamKey = (DataStateKey<dynamic>? key, Type);

class TestableTreeStateMachine extends TreeStateMachine {
  TestableTreeStateMachine._(
      super.machine, super.failedMessagePolicy, super.log, super.name)
      : super._();
  factory TestableTreeStateMachine(
    TreeNode Function(TreeBuildContext) buildRoot, {
    PostMessageErrorPolicy failedMessagePolicy =
        PostMessageErrorPolicy.convertToFailedMessage,
    String? name,
  }) {
    TreeStateMachine? treeMachine;
    var buildCtx = TreeBuildContext();
    var rootNode = buildRoot(buildCtx);
    var machine = Machine(
      rootNode,
      buildCtx.nodes,
      (message) => treeMachine!._queueMessage(message),
    );
    var log = Logger('tree_state_machine.TestableTreeStateMachine');
    return treeMachine = TestableTreeStateMachine._(
        machine, failedMessagePolicy, log, name ?? '');
  }

  /// Gets the internal machine for testing purposes
  Machine get machine => _machine;
}
