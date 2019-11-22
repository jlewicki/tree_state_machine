import 'dart:async';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

// Core state machine operations
class Machine {
  final TreeNode rootNode;
  final Map<StateKey, TreeNode> nodes;

  Machine(this.rootNode, this.nodes);

  Future<TransitionContext> enterInitialState(TreeNode initialNode) async {
    final transCtx = MachineTransitionContext(rootNode, initialNode);

    // States along the path from the root state to the requested initial state.
    var entryPath = initialNode.selfAndAncestors().toList().reversed;

    // If the initial state is not a leaf, we need to follow the initialChild of each descendant,
    // until we reach a leaf.
    if (!initialNode.isLeaf) {
      entryPath = entryPath.followedBy(_descendInitialChildren(initialNode, transCtx));
    }

    await _enterStates(entryPath, transCtx);
    return transCtx;
  }

  Iterable<TreeNode> _descendInitialChildren(
    TreeNode parentNode,
    MachineTransitionContext ctx,
  ) sync* {
    var currentNode = parentNode;
    while (!currentNode.isLeaf) {
      final initialChild = ctx.onInitialChild(currentNode);
      yield initialChild;
      currentNode = initialChild;
    }
  }

  // Is it possible to return FutureOr?
  Future<void> _enterStates(
    Iterable<TreeNode> nodesToEnter,
    MachineTransitionContext transCtx,
  ) async {
    for (final node in nodesToEnter) {
      var result = transCtx.onEnter(node);
      if (result is Future<void>) {
        await result;
      }
    }
  }

  // Future<void> _exitStates(Iterable<TreeNode> nodesToExit, TransitionContext transCtx) async {
  //   for (final node in nodesToExit) {
  //     var result = node.handler().onExit(transCtx);
  //     if (result is Future<void>) {
  //       await result;
  //     }
  //   }
  // }
}

class MachineTransitionContext implements TransitionContext {
  final TreeNode fromNode;
  TreeNode toNode;
  final List<TreeNode> _enteredNodes = [];
  final List<TreeNode> _exitedNodes = [];

  MachineTransitionContext(this.fromNode, this.toNode);

  @override
  TreeStateRef get fromState => TreeStateRef(fromNode.key);

  @override
  TreeStateRef get toState => TreeStateRef(toNode.key);

  @override
  Iterable<TreeStateRef> transitionPath() {
    return _exitedNodes.followedBy(_enteredNodes).map((node) => TreeStateRef(node.key));
  }

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

    toNode = initialChild;
    return initialChild;
  }

  FutureOr<void> onEnter(TreeNode node) {
    final result = node.state().onEnter(this);
    _enteredNodes.add(node);
    return result;
  }

  FutureOr<void> onExit(TreeNode node) {
    final result = node.state().onExit(this);
    _exitedNodes.add(node);
    return result;
  }
}
