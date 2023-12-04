import 'dart:async';
import 'dart:collection';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/initial_state_data.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Provides methods for processing messages and performing state transitions.
///
/// [Machine] defines the core state machine engine, and is not intended for direct use by an
/// application. [TreeStateMachine] should be used instead.
class Machine {
  final MachineNode rootNode;
  final Map<StateKey, MachineNode> nodes;
  final void Function(Object message) _queueMessage;
  final Logger _log;
  MachineNode? _currentLeafNode;

  Machine._(this.rootNode, this.nodes, this._queueMessage, this._log);

  factory Machine(
    TreeNode rootNode,
    Map<StateKey, TreeNode> nodesByKey,
    void Function(Object message) queueMessage, {
    String? logName,
  }) {
    // Add an extra node to represent externally stopped state
    _addStoppedNode(rootNode, nodesByKey);

    var log = Logger('tree_state_machine.Machine${logName != null ? '.$logName' : ''}');
    var machineRoot = MachineNode(rootNode, log);
    var machineNodes = HashMap<StateKey, MachineNode>();
    for (var entry in nodesByKey.entries) {
      machineNodes[entry.key] = MachineNode(entry.value, log);
    }

    return Machine._(machineRoot, machineNodes, queueMessage, log);
  }

  /// The current leaf node for the state machine. Messages will be dispatched to the
  /// [TreeNode.state] of this node for processing.
  TreeNode? get currentLeaf => _currentLeafNode?.treeNode;

  /// Enters the initial state of the state machine.
  ///
  /// Each state between the root state and the initial leaf state of the state machine will be
  /// entered. The initial leaf state is determined by following the initial child path starting at
  /// the root state, or the state identified by [initialState].
  ///
  /// Additionally, if [initialData] contains data values for any data states that are entered,
  /// those values are used when realizing the initial data values for those states. The initial
  /// data functions associated with those state will *not* be called.
  ///
  /// Returns a future yielding a [MachineTransitionContext] that describes the states that were
  /// entered.
  Future<Transition> enterInitialState([StateKey? initialStateKey, InitialStateData? initialData]) {
    final initialNode = initialStateKey != null ? nodes[initialStateKey] : rootNode;
    if (initialNode == null) {
      throw ArgumentError.value(
        initialStateKey.toString(),
        'initalStateKey',
        'This TreeStateMachine does not contain the specified initial state.',
      );
    }
    final path = MachineTransition.enterFromRoot(rootNode.treeNode, to: initialNode.treeNode);
    return _doTransition(path, initialStateData: initialData);
  }

  Future<ProcessedMessage> processMessage(Object message, [StateKey? initialStateKey]) async {
    _log.fine('Processing message $message');

    if (_currentLeafNode == null) {
      final initialStateKey_ = initialStateKey ?? rootNode.treeNode.key;
      await enterInitialState(initialStateKey_);
    }

    // If the state machine is in a final state, do not dispatch the message for processing,
    // since there is no point.
    assert(_currentLeafNode != null);
    if (currentLeaf!.isFinalLeaf) {
      _log.fine('Current state is final, result is UnhandledMessage');
      final msgProcessed = UnhandledMessage(message, _currentLeafNode!.treeNode.key, const []);
      return Future.value(msgProcessed);
    }

    final msgCtx = MachineMessageContext(message, _currentLeafNode!.treeNode, this);

    final msgResult = identical(message, stopMessage)
        ? StopResult.value
        : await _handleMessage(_currentLeafNode!.treeNode, msgCtx);

    final msgProcessed = await _handleMessageResult(msgResult, msgCtx);

    msgCtx.dispose();
    return msgProcessed;
  }

  // Invokes on message on the specified node, and each of its ancestor nodes, until the message is
  // handled, or the root node is reached.
  Future<MessageResult> _handleMessage(TreeNode node, MachineMessageContext msgCtx) async {
    MessageResult msgResult;
    TreeNode? currentNode = node;
    do {
      var currentKey = currentNode!.key;
      _log.fine(() => "Dispatching message to state '$currentKey'");
      final futureOr = msgCtx.onMessage(currentNode);
      msgResult = (futureOr is Future<MessageResult>) ? await futureOr : futureOr;
      _log.fine(
          () => "State '$currentKey' processed message ${msgCtx.message} and returned $msgResult");
      currentNode = currentNode.parent;
    } while (msgResult is UnhandledResult && currentNode != null);
    return msgResult;
  }

  FutureOr<ProcessedMessage> _handleMessageResult(
    MessageResult result,
    MachineMessageContext msgCtx,
  ) async {
    if (result is GoToResult) {
      return _handleGoTo(result, msgCtx);
    } else if (result is UnhandledResult) {
      return _handleUnhandled(msgCtx);
    } else if (result is InternalTransitionResult) {
      return _handleInternalTransition(result, msgCtx);
    } else if (result is SelfTransitionResult) {
      return _handleSelfTransition(result, msgCtx);
    } else if (result is StopResult) {
      return _handleStop(msgCtx);
    }
    throw StateError('Unrecognized message result ${result.runtimeType}');
  }

  Future<HandledMessage> _handleGoTo(
    GoToResult result,
    MachineMessageContext msgCtx,
  ) async {
    var toNode = _treeNode(result.targetStateKey);
    if (result.reenterTarget && toNode.parent == null) {
      throw StateError('Re-entering the root node is invalid.');
    }
    final requestedTransition = MachineTransition.between(
      msgCtx.receivingLeafNode,
      toNode,
      reenterTarget: result.reenterTarget,
    );
    final transition = await _doTransition(
      requestedTransition,
      transitionAction: result.transitionAction,
      payload: result.payload,
    );
    return HandledMessage(
      msgCtx.message,
      msgCtx.receivingLeafNode.key,
      msgCtx.handlingNode.key,
      transition,
    );
  }

  UnhandledMessage _handleUnhandled(MachineMessageContext msgCtx) {
    assert(msgCtx.notifiedNodes.length >= 2,
        'At least 2 nodes (a leaf and the root) should have been notified');
    return UnhandledMessage(
      msgCtx.message,
      msgCtx.receivingLeafNode.key,
      msgCtx.notifiedNodes.map((mn) => mn.key),
    );
  }

  HandledMessage _handleInternalTransition(
    InternalTransitionResult result,
    MachineMessageContext msgCtx,
  ) {
    // Note that an internal transition means that the current leaf state is maintained, even if
    // the internal transition is returned by an ancestor node.
    return HandledMessage(msgCtx.message, msgCtx.receivingLeafNode.key, msgCtx.handlingNode.key);
  }

  Future<HandledMessage> _handleSelfTransition(
    SelfTransitionResult result,
    MachineMessageContext msgCtx,
  ) async {
    if (msgCtx.handlingNode.parent == null) {
      throw StateError('Self-transitions from the root node are invalid.');
    }
    // Note that the handling node might be different from the receiving node. That is, the
    // receiving node might not handle a message, but one of its ancestor nodes could return
    // a self transition. In this case there is some ambiguity. The ancestor state is indicating
    // that it should be exited and re-entered, but does that mean:
    // - the initialChild path of the ancestor should be followed to determine the appropriate leaf
    //   state?
    // - the current leaf state should be maintained?
    // This implementation follows the second approach, since it seems more consistent with the
    // notion of an internal transition.
    //
    // Note that all of the states from the current leaf state to the handling ancestor node will be
    // re-entered.
    final path = MachineTransition.reenter(
      msgCtx.receivingLeafNode,
      from: msgCtx.handlingNode.parent ?? rootNode.treeNode,
    );
    final transition = await _doTransition(path, transitionAction: result.transitionAction);
    return HandledMessage(
      msgCtx.message,
      msgCtx.receivingLeafNode.key,
      msgCtx.handlingNode.key,
      transition,
    );
  }

  Future<HandledMessage> _handleStop(MachineMessageContext msgCtx) async {
    final toNode = _treeNode(stoppedStateKey);
    final path = MachineTransition.between(msgCtx.receivingLeafNode, toNode);
    final transition = await _doTransition(path);
    return HandledMessage(
      msgCtx.message,
      stoppedStateKey,
      stoppedStateKey,
      transition,
    );
  }

  Future<Transition> _doTransition(
    MachineTransition path, {
    TransitionHandler? transitionAction,
    Object? payload,
    InitialStateData? initialStateData,
  }) async {
    var transCtx = MachineTransitionContext(this, path, payload);

    var exitHandlers = path.exitingNodes.map((n) {
      return () => transCtx.onExit(n);
    });
    final entryHandlers = path.enteringNodes.map((n) {
      return initialStateData != null && n.state is DataTreeState
          ? () {
              var initialData = initialStateData(n.key);
              if (initialData != null) {
                (n.state as DataTreeState).initializeData(transCtx, initialData);
              }
              return transCtx.onEnter(n);
            }
          : () => transCtx.onEnter(n);
    });

    // Note that _initialChildPath iterates on demand, so next child won't be computed until
    // current child is entered.
    var initialChildPath = _initialChildPath(path.toNode, transCtx);
    var initialChildHandlers = initialChildPath.map((n) {
      return () => transCtx.onEnter(n);
    });

    FutureOr<void> actionHandler() {
      if (transitionAction != null) {
        _log.fine('Executing transition action');
        return transitionAction(transCtx);
      }
    }

    void bookkeepingHandler() {
      var node = transCtx.currentNode;
      assert(node.isLeaf, 'Transition did not end at a leaf node');
      _log.fine(() => "Transitioned to ${node.isFinalLeaf ? 'final' : ''} state '${node.key}'");
      _currentLeafNode = nodes[node.key]!;
    }

    var f = _runTransitionHandlers(
      transCtx,
      exitHandlers
          .followedBy([actionHandler])
          .followedBy(entryHandlers)
          .followedBy(initialChildHandlers)
          .followedBy([bookkeepingHandler])
          .iterator,
    );
    await f;

    final transition = transCtx.toTransition();
    transCtx.dispose();
    return transition;
  }

  FutureOr<void> _runTransitionHandlers(
    TransitionContext transCtx,
    Iterator<FutureOr<void> Function()> handlerIterator,
  ) {
    while (handlerIterator.moveNext()) {
      var handler = handlerIterator.current;
      var result = handler();
      if (result is Future<void>) {
        return result.then((_) => _runTransitionHandlers(transCtx, handlerIterator));
      }
    }
  }

  Iterable<TreeNode> _initialChildPath(
    TreeNode parentNode,
    MachineTransitionContext transCtx,
  ) sync* {
    var currentNode = parentNode;
    while (!currentNode.isLeaf) {
      var parentOfCurrent = currentNode;
      currentNode = transCtx.onInitialChild(currentNode);
      _log.finer(
          "State '${parentOfCurrent.key}' returned initial child state '${currentNode.key}'");
      yield currentNode;
    }
  }

  Dispose _schedule(
    StateKey timerOwner,
    Object Function() message,
    Duration duration,
    bool periodic,
  ) {
    ArgumentError.checkNotNull(message, 'message');
    if (periodic && duration.inMicroseconds < 100) {
      // 100 is somewhat arbitrary, but we dont want to flood the event queue.
      throw ArgumentError.value(
        duration.inMicroseconds,
        'duration',
        'Duration must be greater than 100 microseconds',
      );
    }

    var canceled = false;
    void postMessage() {
      if (!canceled) {
        var msg = message();
        _log.fine("State '$timerOwner' is posting sheduled message $msg");
        _queueMessage(msg);
      }
    }

    final timer = periodic
        ? Timer.periodic(duration, (timer) => postMessage())
        : Timer(duration, postMessage);
    // Associate the timer with the tree node that is currently processing the message when this
    // method is called.
    _node(timerOwner).addTimer(timer);
    return () {
      canceled = true;
      timer.cancel();
      _log.fine("Canceled timer for state '$timerOwner'");
    };
  }

  MachineNode _node(StateKey key) {
    final machineNode = nodes[key];
    if (machineNode == null) {
      throw StateError(
        'This TreeStateMachine does not contain the specified state $key.',
      );
    }
    return machineNode;
  }

  TreeNode _treeNode(StateKey key) {
    final machineNode = _node(key);
    return machineNode.treeNode;
  }

  static void _addStoppedNode(TreeNode rootNode, Map<StateKey, TreeNode> nodesByKey) {
    var stoppedNode =
        TreeNode(NodeType.finalLeafNode, stoppedStateKey, rootNode, (_) => _stoppedState, null);
    nodesByKey[stoppedStateKey] = stoppedNode;
    rootNode.children.add(stoppedNode);
  }
}

class MachineMessageContext with DisposableMixin implements MessageContext {
  final Machine _machine;

  /// The leaf node that received the message.
  final TreeNode receivingLeafNode;

  /// The nodes, starting at the receiving leaf node, that were notified of the message.
  final List<TreeNode> notifiedNodes = [];

  /// The node that handled the message. That is, the node that returned a [MessageResult] other
  /// than [UnhandledResult].
  TreeNode get handlingNode => notifiedNodes.last;

  MachineMessageContext(this.message, this.receivingLeafNode, this._machine)
      : assert(receivingLeafNode.isLeaf);

  @override
  DataValue<D>? data<D>([DataStateKey<D>? key]) {
    assert(notifiedNodes.isNotEmpty);
    return notifiedNodes.last.selfOrAncestorDataValue<D>(key: key);
  }

  @override
  final Object message;

  @override
  final Map<String, Object> appData = {};

  @override
  MessageResult goTo(
    StateKey targetStateKey, {
    TransitionHandler? transitionAction,
    Object? payload,
    bool reenterTarget = false,
  }) {
    _throwIfDisposed();
    return GoToResult(targetStateKey, transitionAction, payload, reenterTarget);
  }

  @override
  MessageResult stay() {
    _throwIfDisposed();
    return InternalTransitionResult.value;
  }

  @override
  MessageResult goToSelf({TransitionHandler? transitionAction}) {
    _throwIfDisposed();
    return SelfTransitionResult(transitionAction);
  }

  @override
  MessageResult unhandled() {
    _throwIfDisposed();
    return UnhandledResult.value;
  }

  @override
  void post(FutureOr<Object> message) {
    _throwIfDisposed();
    ArgumentError.checkNotNull(message, 'message');
    if (message is Future<Object>) {
      message.then(_machine._queueMessage);
    } else {
      _machine._queueMessage(message);
    }
  }

  @override
  Dispose schedule(
    Object Function() message, {
    Duration duration = const Duration(),
    bool periodic = false,
  }) {
    _throwIfDisposed();
    return _machine._schedule(notifiedNodes.last.key, message, duration, periodic);
  }

  FutureOr<MessageResult> onMessage(TreeNode node) {
    notifiedNodes.add(node);
    return node.state.onMessage(this);
  }
}

class MachineTransitionContext with DisposableMixin implements TransitionContext {
  final Machine _machine;
  final MachineTransition _requestedTransition;
  final Object? _payload;
  final List<TreeNode> _enteredNodes = [];
  final List<TreeNode> _exitedNodes = [];
  TreeNode _currentNode;

  MachineTransitionContext(this._machine, this._requestedTransition, this._payload)
      : _currentNode = _requestedTransition.fromNode,
        // In general we always start a transition at a leaf node. However, when the state machine
        // starts, there is a transition from the root node to the initial starting state for the
        // machine.
        assert(_requestedTransition.fromNode.isLeaf || _requestedTransition.fromNode.isRoot,
            'Transition did not start at a leaf or root node.');

  @override
  Object? get payload => _payload;

  @override
  Transition get requestedTransition => _requestedTransition;

  @override
  Iterable<StateKey> get entered => _enteredNodes.map((n) => n.key);

  @override
  Iterable<StateKey> get exited => _exitedNodes.map((n) => n.key);

  @override
  StateKey get lca => _requestedTransition.lca;

  @override
  DataValue<D>? data<D>([DataStateKey<D>? key]) {
    return _currentNode.selfOrAncestorDataValue<D>(key: key);
  }

  TreeNode get currentNode => _currentNode;

  Transition toTransition() {
    return Transition(_requestedTransition.from, _currentNode.key, lca, exited, entered,
        _enteredNodes.last.isFinalLeaf);
  }

  @override
  void post(FutureOr<Object> message) {
    _throwIfDisposed();
    message.bind(_machine._queueMessage);
  }

  @override
  Dispose schedule(
    Object Function() message, {
    Duration duration = const Duration(),
    bool periodic = false,
  }) {
    _throwIfDisposed();
    return _machine._schedule(_currentNode.key, message, duration, periodic);
  }

  TreeNode onInitialChild(TreeNode parentNode) {
    assert(parentNode.getInitialChild != null);

    final initialChildKey = parentNode.getInitialChild!(this);
    final initialChild = parentNode.children.firstWhereOrNull((c) => c.key == initialChildKey);
    if (initialChild == null) {
      throw StateError('Unable to find initialChild $initialChildKey for ${parentNode.key}.');
    }
    return initialChild;
  }

  FutureOr<void> onEnter(TreeNode node) {
    _currentNode = node;
    _enteredNodes.add(node);
    _machine._log.fine("Entering state '${node.key}'");
    return node.state.onEnter(this);
  }

  FutureOr<void> onExit(TreeNode node) {
    _currentNode = node;
    _exitedNodes.add(node);
    _machine._node(node.key).cancelTimers();
    _machine._log.fine("Exiting state '${node.key}'");
    return node.state.onExit(this);
  }
}

class MachineTransition implements Transition {
  /// The starting leaf state of the path.
  final TreeNode fromNode;

  /// The final state of the path.
  ///
  /// This may be either a leaf or non-leaf state.
  final TreeNode toNode;

  /// The states that will be entered as the path is traversed.
  final List<TreeNode> enteringNodes;

  /// The states that will be exited as the path is traversed.
  final List<TreeNode> exitingNodes;

  /// The path of nodes to traverse, starting at [from] and ending at [to].
  late final List<TreeNode> nodePath =
      List<TreeNode>.unmodifiable(exitingNodes.followedBy(enteringNodes));

  final TreeNode lcaNode;

  @override
  late final List<StateKey> entryPath = enteringNodes.map((n) => n.key).toList();

  @override
  late final List<StateKey> exitPath = exitingNodes.map((n) => n.key).toList();

  @override
  late final StateKey from = fromNode.key;

  @override
  late final StateKey to = toNode.key;

  @override
  StateKey get lca => lcaNode.key;

  @override
  late final List<StateKey> path = nodePath.map((n) => n.key).toList();

  @override
  bool get isToFinalState => toNode.isFinalLeaf;

  /// Constructs a [TransitionPath] instance.
  MachineTransition._(
    this.fromNode,
    this.toNode,
    this.lcaNode,
    Iterable<TreeNode> exitingNodes,
    Iterable<TreeNode> enteringNodes,
  )   : exitingNodes = List.unmodifiable(exitingNodes),
        enteringNodes = List.unmodifiable(enteringNodes);

  factory MachineTransition.between(TreeNode from, TreeNode to, {bool reenterTarget = false}) {
    final lca = from.lcaWith(to);
    final reenteringAncestor = reenterTarget && lca == to;
    final reenteringCurrent = reenterTarget && from == to;
    final reentryNode = reenteringAncestor || reenteringCurrent ? [to] : const <TreeNode>[];
    final exiting =
        from.selfAndAncestors().takeWhile((n) => n != lca).followedBy(reentryNode).toList();
    final entering = reenteringAncestor
        ? reentryNode
        : to.selfAndAncestors().takeWhile((n) => n != lca).toList().reversed.toList();
    return MachineTransition._(from, to, lca, exiting, entering);
  }

  factory MachineTransition.reenter(TreeNode node, {required TreeNode from}) {
    final lca = node.lcaWith(from);
    assert(lca.key == from.key);
    final exiting = node.selfAndAncestors().takeWhile((n) => n != lca).toList();
    final entering = exiting.reversed.toList();
    return MachineTransition._(node, node, lca, exiting, entering);
  }

  factory MachineTransition.enterFromRoot(TreeNode root, {required TreeNode to}) {
    assert(root.isRoot);
    final exiting = <TreeNode>[];
    final entering = to.selfAndAncestors().toList().reversed.toList();
    return MachineTransition._(root, to, root, exiting, entering);
  }
}

mixin DisposableMixin {
  bool _disposed = false;
  bool get isDisposed => _disposed;
  void dispose() => _disposed = true;

  void _throwIfDisposed() {
    if (isDisposed) {
      throw DisposedError('This $runtimeType has been disposed.');
    }
  }
}

/// Keeps track of resources associated with a tree node.
class MachineNode {
  final TreeNode treeNode;
  final List<Timer> _timers = [];
  final Logger _log;
  MachineNode(this.treeNode, this._log);

  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  void cancelTimers() {
    if (_timers.isNotEmpty) {
      _log.fine("Canceling timers for state '${treeNode.key}'");
      for (final timer in _timers) {
        timer.cancel();
      }
    }
  }

  void dispose() {
    cancelTimers();
    treeNode.dispose();
  }
}

final stopMessage = Object();

final _stoppedState = DelegatingTreeState(
  (ctx) => throw StateError('Can not send message to a final state'),
  (ctx) => {},
  (ctx) => throw StateError('Can not leave a final state.'),
  null,
);
