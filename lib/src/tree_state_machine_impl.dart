import 'dart:async';
import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/data_provider.dart';
import 'package:tree_state_machine/src/utility.dart';

import 'errors.dart';
import 'tree_node.dart';
import 'tree_state.dart';

// Core state machine operations
class Machine {
  final MachineNode rootNode;
  final Map<StateKey, MachineNode> nodes;
  MachineNode _currentNode;
  void Function(Object message) _queueMessage;

  Machine._(this.rootNode, this.nodes, this._queueMessage);

  factory Machine(
    TreeNode rootNode,
    Map<StateKey, TreeNode> nodesByKey,
    void Function(Object message) queueMessage,
  ) {
    // Add an extra node to represent externally stopped state
    _addStoppedNode(rootNode, nodesByKey);

    final machineRoot = MachineNode(rootNode);
    final machineNodes = HashMap<StateKey, MachineNode>();
    for (final entry in nodesByKey.entries) {
      machineNodes[entry.key] = MachineNode(entry.value);
    }

    return Machine._(machineRoot, machineNodes, queueMessage);
  }

  TreeNode get currentNode => _currentNode?.node;

  /// Enters the initial state of the state machine.
  ///
  /// Each state between the root state and the initial leaf state of the state machine will be
  /// entered. The initial leaf state is determined by following the initial child path starting at
  /// the root state, or the state identified by [initialStateKey].
  ///
  /// Returns a future yielding a [MachineTransitionContext] that describes the states that were
  /// entered.
  Future<Transition> enterInitialState([StateKey initialStateKey]) {
    final initialNode = initialStateKey != null ? nodes[initialStateKey] : rootNode;
    if (initialNode == null) {
      throw ArgumentError.value(
        initialStateKey,
        'initalStateKey',
        'This TreeStateMachine does not contain the specified initial state.',
      );
    }
    final path = NodePath.enterFromRoot(rootNode.node, initialNode.node);
    return _doTransition(path);
  }

  /// Processes the specified message by dispatching it to the current state.
  ///
  /// Returns a future yielding a [ProcessedMessage] that describes how the message was processed,
  /// and any state transition that occurred.
  Future<ProcessedMessage> processMessage(Object message, [StateKey initialStateKey]) async {
    // Auto initializing makes testing easier, but may want to rethink this.
    if (_currentNode == null) {
      final _initialStateKey = initialStateKey ?? rootNode.node.key;
      final initialNode = nodes[_initialStateKey];
      assert(initialNode != null, 'Unable to find initial state $initialStateKey');
      await enterInitialState(initialNode.node.key);
    }

    // If the state machine is in a final state, do not dispatch the message for processing,
    // since there is no point.
    if (currentNode.isFinal) {
      final msgProcessed = UnhandledMessage(message, currentNode.key, const []);
      return Future.value(msgProcessed);
    }

    final msgCtx = MachineMessageContext(message, _currentNode.node, this);
    final msgResult =
        identical(message, stopMessage) ? StopResult() : await _handleMessage(currentNode, msgCtx);
    final msgProcessed = await _handleMessageResult(msgResult, msgCtx);
    msgCtx.dispose();
    return msgProcessed;
  }

  // Invokes on message on the specified node, and each of its ancestor nodes, until the message is
  // handled, or the root node is reached.
  Future<MessageResult> _handleMessage(TreeNode node, MachineMessageContext msgCtx) async {
    MessageResult msgResult;
    var currentNode = node;
    do {
      final futureOr = msgCtx.onMessage(currentNode);
      msgResult = (futureOr is Future) ? await futureOr : futureOr as MessageResult;
      if (msgResult == null) {
        throw StateError('State ${currentNode.key} returned null from onMessage.');
      }
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
    assert(false, 'Unrecognized message result ${result.runtimeType}');
    return null;
  }

  Future<HandledMessage> _handleGoTo(
    GoToResult result,
    MachineMessageContext msgCtx, {
    bool isSelfTransition = false,
  }) async {
    var toNode = _node(result.toStateKey).node;
    if (result.reenterAncestor && toNode.parent == null) {
      throw StateError('Re-entering the root node is invalid.');
    }
    final path = NodePath(msgCtx.receivingNode, toNode, reenterAncestor: result.reenterAncestor);
    final transition = await _doTransition(path, result.transitionAction, result.payload);
    return HandledMessage(
      msgCtx.message,
      msgCtx.receivingNode.key,
      msgCtx.handlingNode.key,
      transition,
    );
  }

  UnhandledMessage _handleUnhandled(MachineMessageContext msgCtx) {
    assert(msgCtx.notifiedNodes.length >= 2,
        'At least 2 nodes (a leaf and the root) should have been notified');
    return UnhandledMessage(
      msgCtx.message,
      msgCtx.receivingNode.key,
      msgCtx.notifiedNodes.map((mn) => mn.key),
    );
  }

  HandledMessage _handleInternalTransition(
    InternalTransitionResult result,
    MachineMessageContext msgCtx,
  ) =>
      // Note that an internal transition means that the current leaf state is maintained, even if
      // the internal transition is returned by an ancestor node.
      HandledMessage(msgCtx.message, msgCtx.receivingNode.key, msgCtx.handlingNode.key);

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
    final path = NodePath.reenter(msgCtx.receivingNode, msgCtx.handlingNode.parent);
    final transition = await _doTransition(path, result.transitionAction);
    return HandledMessage(
      msgCtx.message,
      msgCtx.receivingNode.key,
      msgCtx.handlingNode.key,
      transition,
    );
  }

  Future<HandledMessage> _handleStop(MachineMessageContext msgCtx) async {
    final toNode = _node(StoppedTreeState.key);
    final path = NodePath(msgCtx.receivingNode, toNode.node);
    final transition = await _doTransition(path);
    return HandledMessage(
      msgCtx.message,
      StoppedTreeState.key,
      StoppedTreeState.key,
      transition,
    );
  }

  Future<Transition> _doTransition(
    NodePath path, [
    TransitionHandler transitionAction,
    Object payload,
  ]) async {
    final transCtx = MachineTransitionContext(path, this, payload);

    final exitHandlers = path.exiting.map((n) => () => transCtx.onExit(n));
    final actionHandler = () => (transitionAction ?? emptyTransitionHandler)(transCtx);
    final entryHandlers = path.entering.map((n) => () => transCtx.onEnter(n));
    final initialChildPath = _initialChildPath(path.to, transCtx);
    // Note that initialChildPath iterates on demand, so next child won't be computed until
    // current child is entered.
    final initialChildHandlers = initialChildPath.map((n) => () => transCtx.onEnter(n));
    final bookkeepingHandler = () {
      assert(transCtx.endNode.isLeaf, 'Transition did not end at a leaf node');
      _currentNode = nodes[transCtx.endNode.key];
    };

    await _runTransitionHandlers(
      transCtx,
      exitHandlers
          .followedBy([actionHandler])
          .followedBy(entryHandlers)
          .followedBy(initialChildHandlers)
          .followedBy([bookkeepingHandler])
          .iterator,
    );

    final transition = transCtx.toTransition();
    transCtx.dispose();
    return transition;
  }

  Iterable<TreeNode> _initialChildPath(
    TreeNode parentNode,
    MachineTransitionContext transCtx,
  ) sync* {
    var currentNode = parentNode;
    while (!currentNode.isLeaf) {
      currentNode = transCtx.onInitialChild(currentNode);
      yield currentNode;
    }
  }

  FutureOr<void> _runTransitionHandlers(
    TransitionContext transCtx,
    Iterator<FutureOr<void> Function()> handlers,
  ) {
    while (handlers.moveNext()) {
      final result = handlers.current();
      if (result is Future<void>) {
        return result.then((Object _) => _runTransitionHandlers(transCtx, handlers));
      }
    }
    return transCtx;
  }

  MachineNode _node(StateKey key, [bool throwIfNotFound = true]) {
    final machineNode = nodes[key];
    if (key == null && throwIfNotFound) {
      throw StateError(
        'This TreeStateMachine does not contain the specified state $key.',
      );
    }
    return machineNode;
  }

  static void _addStoppedNode(TreeNode rootNode, Map<StateKey, TreeNode> nodesByKey) {
    final stoppedState =
        TreeNode.finalNode(StoppedTreeState.key, rootNode, (_) => StoppedTreeState());
    nodesByKey[StoppedTreeState.key] = stoppedState;
    rootNode.children.add(stoppedState);
  }
}

class MachineTransitionContext with DisposableMixin implements TransitionContext {
  final NodePath nodePath;
  TreeNode toNode;
  final Object _payload;
  final List<TreeNode> _enteredNodes = [];
  final List<TreeNode> _exitedNodes = [];
  final Machine _machine;

  MachineTransitionContext(
    this.nodePath,
    this._machine,
    this._payload,
  ) : toNode = nodePath.to {
    // In general we always start a transition at a leaf node. However, when the state machine
    // starts, there is a transition from the root node to the initial starting state for the
    // machine.
    assert(nodePath.from.isLeaf || nodePath.from.isRoot,
        'Transition did not start at a leaf or root node.');
  }

  @override
  StateKey get from => nodePath.from.key;
  @override
  StateKey get to => nodePath.to.key;
  @override
  Iterable<StateKey> get path => nodePath.path.map((n) => n.key);
  @override
  Iterable<StateKey> get exited => _exitedNodes.map((n) => n.key);
  @override
  Iterable<StateKey> get entered => _enteredNodes.map((n) => n.key);
  @override
  Iterable<StateKey> traversed() => exited.followedBy(entered);
  @override
  StateKey get end => entered.last;
  @override
  Object get payload => _payload;

  @override
  void post(FutureOr<Object> message) {
    _throwIfDisposed();
    ArgumentError.checkNotNull(message, 'message');
    if (message is Future) {
      message.then(_machine._queueMessage);
    } else {
      _machine._queueMessage(message);
    }
  }

  @experimental
  D data<D>([StateKey key]) {
    return _enteredNodes.last.selfOrAncestorDataStream<D>(key)?.value;
  }

  @experimental
  void replaceData<D>(D Function() replace, [StateKey key]) {
    return _enteredNodes.last.selfOrAncestorDataProvider<D>(key)?.replace(replace);
  }

  Iterable<TreeNode> get exitedNodes => _exitedNodes;
  Iterable<TreeNode> get enteredNodes => _enteredNodes;
  TreeNode get endNode => _enteredNodes.last;

  TreeNode onInitialChild(TreeNode parentNode) {
    final initialChildKey = parentNode.initialChild(this);
    if (initialChildKey == null) {
      throw StateError('initialChild for ${parentNode.key} returned null');
    }

    final initialChild =
        parentNode.children.firstWhere((c) => c.key == initialChildKey, orElse: () => null);
    if (initialChild == null) {
      throw StateError('Unable to find initialChild $initialChildKey for ${parentNode.key}.');
    }

    // Update toNode as initial child is calculated
    toNode = initialChild;
    return initialChild;
  }

  FutureOr<void> onEnter(TreeNode node) {
    _enteredNodes.add(node);
    return node.state().onEnter(this);
  }

  FutureOr<void> onExit(TreeNode node) {
    _exitedNodes.add(node);
    // Resetting the provider each time the state is exited ensures that the state will state with
    // a fresh data value each time the state is entered.
    node.lazyProvider?.reset();
    _machine._node(node.key).cancelTimers();
    return node.state().onExit(this);
  }

  Transition toTransition() {
    assert(endNode.isLeaf, 'Transition did not end at a leaf node.');
    return Transition(
        from, end, traversed(), exited, entered, endNode.selfAndAncestors().map((n) => n.key));
  }

  void _throwIfDisposed() {
    if (isDisposed) {
      throw StateError('This TransitionContext has been disposed.');
    }
  }
}

class MachineMessageContext with DisposableMixin implements MessageContext {
  final Machine _machine;

  /// The leaf node that received the message
  final TreeNode receivingNode;

  /// The nodes, starting at the receiving leaf node, that were notified of the message.
  final List<TreeNode> notifiedNodes = [];

  /// The node that handled the message. That is, the node that returned a [MessageResult] other
  /// than [UnhandledResult].
  TreeNode get handlingNode => notifiedNodes.last;

  MachineMessageContext(this.message, this.receivingNode, this._machine)
      : assert(message != null),
        assert(receivingNode != null),
        assert(receivingNode.isLeaf);

  @override
  final Object message;

  @override
  MessageResult goTo(
    StateKey targetStateKey, {
    TransitionHandler transitionAction,
    Object payload,
    bool reenterAncestor = false,
  }) {
    _throwIfDisposed();
    return GoToResult(targetStateKey, transitionAction, payload, reenterAncestor);
  }

  @override
  MessageResult stay() {
    _throwIfDisposed();
    return InternalTransitionResult.value;
  }

  @override
  MessageResult goToSelf({TransitionHandler transitionAction}) {
    _throwIfDisposed();
    return SelfTransitionResult(transitionAction);
  }

  @override
  MessageResult unhandled() {
    _throwIfDisposed();
    return UnhandledResult.value;
  }

  @override
  Dispose schedule(
    Object Function() message, {
    Duration duration = const Duration(),
    bool periodic = false,
  }) {
    _throwIfDisposed();
    ArgumentError.checkNotNull(message, 'message');
    if (periodic && duration.inMicroseconds < 100) {
      // 100 is somewhat arbitrary, but we dont want to flood the event queue.
      throw ArgumentError.value(
        duration.inMicroseconds,
        'duration',
        'Duration must be greater than 100 microseconds',
      );
    }
    final postMessage = () => _machine._queueMessage(message());
    final timer = periodic
        ? Timer.periodic(duration, (timer) => postMessage())
        : Timer(duration, postMessage);
    // Associate the timer with the tree node that is currently processing the message when this
    // method is called.
    _machine._node(notifiedNodes.last.key).addTimer(timer);
    return timer.cancel;
  }

  @override
  D data<D>([StateKey key]) {
    assert(notifiedNodes.isNotEmpty);
    return notifiedNodes.last.selfOrAncestorDataStream<D>(key)?.value;
  }

  @override
  void replaceData<D>(D Function(D) replace, {StateKey key}) {
    _throwIfDisposed();
    final provider = _resolveDataProvider<D>(key);
    provider.replace(() => replace(provider.data));
  }

  @override
  void updateData<D>(void Function(D) update, {StateKey key}) {
    _throwIfDisposed();
    final provider = _resolveDataProvider<D>(key);
    provider.update(() => update(provider.data));
  }

  FutureOr<MessageResult> onMessage(TreeNode node) {
    notifiedNodes.add(node);
    return node.state().onMessage(this);
  }

  DataProvider<D> _resolveDataProvider<D>(StateKey key) {
    DataProvider<D> provider = notifiedNodes.last.selfOrAncestorDataProvider<D>(key);
    if (provider == null) {
      final msg = key != null
          ? 'Unable to find data provider that matches data type ${TypeLiteral<D>().type} and key $key'
          : 'Unable to find data provider that matches data type ${TypeLiteral<D>().type}';
      throw StateError(msg);
    }
    return provider;
  }

  void _throwIfDisposed() {
    if (isDisposed) {
      throw DisposedError('This MessageContext has been disposed.');
    }
  }
}

mixin DisposableMixin {
  bool _disposed = false;
  bool get isDisposed => _disposed;
  void dispose() => _disposed = true;
}

/// Keeps track of resources associated with a tree node.
class MachineNode {
  final TreeNode node;
  final List<Timer> _timers = [];
  MachineNode(this.node);

  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  void cancelTimers() {
    for (final timer in _timers) {
      timer.cancel();
    }
  }

  void dispose() {
    cancelTimers();
    node?.dispose();
  }
}

final stopMessage = Object();
