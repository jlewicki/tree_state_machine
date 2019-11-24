import 'dart:async';
import 'tree_builders.dart';
import 'tree_state.dart';

// Core state machine operations
class Machine {
  final TreeNode rootNode;
  final Map<StateKey, TreeNode> nodes;

  Machine(this.rootNode, this.nodes);

  Future<MachineTransitionContext> enterInitialState([StateKey initialStateKey]) async {
    final initialNode = initialStateKey != null ? nodes[initialStateKey] : rootNode;
    if (initialNode == null) {
      throw ArgumentError.value(
        initialStateKey,
        'initalStateKey',
        'This TreeStateMachine does not contain the specified initial state.',
      );
    }
    final transCtx = MachineTransitionContext(rootNode, initialNode);
    var entryPath = initialNode.selfAndAncestors().toList().reversed;
    if (!initialNode.isLeaf) {
      entryPath = entryPath.followedBy(_descendInitialChildren(initialNode, transCtx));
    }
    await _enterStates(entryPath, transCtx);
    return transCtx;
  }

  Future<MessageProcessed> processMessage(Object message, StateKey currentStateKey) async {
    final currentNode = nodes[currentStateKey];
    if (currentNode == null) {
      throw ArgumentError.value(
        currentStateKey,
        'currentStateKey',
        'This TreeStateMachine does not contain the specified state.',
      );
    }
    final msgCtx = MachineMessageContext(message, currentNode);
    final msgResult = await _handleMessage(currentNode, msgCtx);
    return _handleMessageResult(msgResult, msgCtx);
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

  FutureOr<MessageProcessed> _handleMessageResult(
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
    }
    assert(false, 'Unrecognized message result ${result.runtimeType}');
    return null;
  }

  Future<HandledMessage> _handleGoTo(
    GoToResult result,
    MachineMessageContext msgCtx, {
    bool isSelfTransition = false,
  }) async {
    var toNode = _node(result.toStateKey);
    final transCtx = MachineTransitionContext(msgCtx.receivingNode, toNode);
    final initialChildren = _descendInitialChildren(toNode, transCtx);
    toNode = initialChildren.isEmpty ? toNode : initialChildren.last;
    final path = _path(msgCtx.receivingNode, toNode);
    await _exitStates(path.exitingNodes, transCtx);
    await _enterStates(path.enteringNodes, transCtx);
    return HandledMessage(
      msgCtx.message,
      msgCtx.receivingNode.key,
      msgCtx.handlingNode.key,
      transCtx.exitedNodes.map((n) => n.key),
      transCtx.enteredNodes.map((n) => n.key),
    );
  }

  UnhandledMessage _handleUnhandled(MachineMessageContext msgCtx) {
    assert(msgCtx.notifiedNodes.length >= 2);
    return UnhandledMessage(
      msgCtx.message,
      msgCtx.receivingNode.key,
      msgCtx.notifiedNodes.map((n) => n.key),
    );
  }

  HandledMessage _handleInternalTransition(
      InternalTransitionResult result, MachineMessageContext msgCtx) {
    // Note that an internal transition means that the current leaf state is maintained, even if
    // the internal transition is returned by an ancestor node.
    return HandledMessage(
        msgCtx.message, msgCtx.receivingNode.key, msgCtx.handlingNode.key, [], []);
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
    final handlingParent = msgCtx.handlingNode.parent;
    final exitingNodes = _path(msgCtx.receivingNode, handlingParent).path;
    final enteringNodes = exitingNodes.toList().reversed;
    final transCtx = MachineTransitionContext(msgCtx.receivingNode, msgCtx.receivingNode);
    await _exitStates(exitingNodes, transCtx);
    await _enterStates(enteringNodes, transCtx);
    return HandledMessage(
      msgCtx.message,
      msgCtx.receivingNode.key,
      msgCtx.handlingNode.key,
      transCtx.exitedNodes.map((n) => n.key),
      transCtx.enteredNodes.map((n) => n.key),
    );
  }

  Iterable<TreeNode> _descendInitialChildren(
    TreeNode parentNode,
    MachineTransitionContext ctx,
  ) {
    final nodes = <TreeNode>[];
    var currentNode = parentNode;
    while (!currentNode.isLeaf) {
      final initialChild = ctx.onInitialChild(currentNode);
      nodes.add(initialChild);
      currentNode = initialChild;
    }
    return nodes;
  }

  Future<void> _enterStates(
    Iterable<TreeNode> nodesToEnter,
    MachineTransitionContext transCtx,
  ) async {
    // If we use recursion/lazy evaluation can we avoid the await?
    for (final node in nodesToEnter) {
      final result = transCtx.onEnter(node);
      if (result is Future<void>) {
        await result;
      }
    }
  }

  Future<void> _exitStates(
    Iterable<TreeNode> nodesToExit,
    MachineTransitionContext transCtx,
  ) async {
    // If we use recursion/lazy evaluation can we avoid the await?
    for (final node in nodesToExit) {
      final result = transCtx.onExit(node);
      if (result is Future<void>) {
        await result;
      }
    }
  }

  NodePath _path(TreeNode from, TreeNode to) {
    final lcaNode = from.lcaWith(to);
    final exitingNodes = from.selfAndAncestors().takeWhile((n) => n != lcaNode).toList();
    final enteringNodes = to.selfAndAncestors().takeWhile((n) => n != lcaNode).toList().reversed;
    return NodePath(exitingNodes, enteringNodes);
  }

  TreeNode _node(StateKey key, [bool throwIfNotFound = true]) {
    final node = nodes[key];
    if (key == null && throwIfNotFound) {
      throw StateError(
        'This TreeStateMachine does not contain the specified state $key.',
      );
    }
    return node;
  }
}

class MachineTransitionContext implements TransitionContext {
  final TreeNode fromNode;
  TreeNode toNode;
  final List<TreeNode> _enteredNodes = [];
  final List<TreeNode> _exitedNodes = [];

  MachineTransitionContext(this.fromNode, this.toNode);

  @override
  StateKey get from => fromNode.key;

  @override
  StateKey get to => toNode.key;

  @override
  Iterable<StateKey> path() => _exitedNodes.followedBy(_enteredNodes).map((node) => node.key);

  Iterable<TreeNode> get exitedNodes => _exitedNodes;
  Iterable<TreeNode> get enteredNodes => _enteredNodes;

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
    final result = node.state().onEnter(this);
    _enteredNodes.add(node);
    if (result is Future<void>) {
      return result;
    }
  }

  FutureOr<void> onExit(TreeNode node) {
    final result = node.state().onExit(this);
    _exitedNodes.add(node);
    if (result is Future<void>) {
      return result;
    }
  }
}

class MachineMessageContext extends MessageContext {
  /// The leaf node that received the message
  final TreeNode receivingNode;

  /// The nodes, starting at the receiving leaf node, that were notified of the message.
  final List<TreeNode> notifiedNodes = [];

  /// The node that handled the message. That is, the node that returned a [MessageResult] other
  /// than [UnhandledResult].
  TreeNode get handlingNode => notifiedNodes.last;

  MachineMessageContext(Object message, this.receivingNode) : super(message);

  FutureOr<MessageResult> onMessage(TreeNode node) {
    notifiedNodes.add(node);
    return node.state().onMessage(this);
  }
}

class NodePath {
  final Iterable<TreeNode> exitingNodes;
  final Iterable<TreeNode> enteringNodes;
  NodePath(this.exitingNodes, this.enteringNodes);
  Iterable<TreeNode> get path => exitingNodes.followedBy(enteringNodes);
}

//.
abstract class MessageProcessed {
  final Object message;
  final StateKey receivingState;
  MessageProcessed(this.message, this.receivingState);
}

class HandledMessage extends MessageProcessed {
  final StateKey handlingState;
  final Iterable<StateKey> exitedStates;
  final Iterable<StateKey> enteredStates;
  HandledMessage(
    Object message,
    StateKey receivingState,
    this.handlingState,
    this.exitedStates,
    this.enteredStates,
  ) : super(message, receivingState);
}

class UnhandledMessage extends MessageProcessed {
  final Iterable<StateKey> notifiedStates;
  UnhandledMessage(Object message, StateKey receivingState, this.notifiedStates)
      : super(message, receivingState);
}

class InvalidMessage extends MessageProcessed {
  InvalidMessage(Object message, StateKey receivingState) : super(message, receivingState);
}
