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
    return _dispatchMessageResult(msgResult, msgCtx);
  }

  Future<MessageResult> _handleMessage(TreeNode node, MachineMessageContext msgCtx) async {
    MessageResult msgResult;
    TreeNode currentNode = node;
    do {
      final futureOr = msgCtx.onMessage(currentNode);
      msgResult = (futureOr is Future) ? await futureOr : futureOr as MessageResult;
      currentNode = currentNode.parent;
    } while (msgResult.isUnhandled && currentNode != null);
    return msgResult;
  }

  Future<MessageProcessed> _dispatchMessageResult(
    MessageResult result,
    MachineMessageContext msgCtx,
  ) async {
    if (result is GoToResult) {
      // Move this code to MachineGoToResult
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
    return null;
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
    TreeNode lcaNode = from.lcaWith(to);
    final exitingNodes = from.selfAndAncestors().takeWhile((n) => n != lcaNode).toList();
    final enteringNodes = to.selfAndAncestors().takeWhile((n) => n != lcaNode).toList().reversed;
    //final initialChildNodes = _descendInitialChildren(to, ctx)
    return NodePath(exitingNodes, enteringNodes);
  }

  TreeNode _node(StateKey key, [throwIfNotFound = true]) {
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
  final TreeNode receivingNode;
  TreeNode handlingNode;

  MachineMessageContext(Object message, this.receivingNode) : super(message);

  FutureOr<MessageResult> onMessage(TreeNode node) {
    handlingNode = node;
    return node.state().onMessage(this);
  }
}

class NodePath {
  final Iterable<TreeNode> exitingNodes;
  final Iterable<TreeNode> enteringNodes;
  NodePath(this.exitingNodes, this.enteringNodes);
}

abstract class MessageProcessed {}

class HandledMessage extends MessageProcessed {
  final Object message;
  final StateKey receivingState;
  final StateKey handlingState;
  final Iterable<StateKey> exitedStates;
  final Iterable<StateKey> enteredStates;
  HandledMessage(
    this.message,
    this.receivingState,
    this.handlingState,
    this.exitedStates,
    this.enteredStates,
  );
}

class UnhandledMessage extends MessageProcessed {
  final Object message;
  final StateKey receivingState;
  final Iterable<StateKey> handlingStates;
  UnhandledMessage(this.message, this.receivingState, this.handlingStates);
}

class InvalidMessage extends MessageProcessed {}
