import 'dart:async';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

// Core state machine operations
class Machine {
  final TreeNode rootNode;
  final Map<StateKey, TreeNode> nodes;

  Machine(this.rootNode, this.nodes);

  Future<TransitionContext> enterInitialState(TreeNode initialNode) async {
    final transCtx = _TransitionContext();

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

  Iterable<TreeNode> _descendInitialChildren(TreeNode parentNode, _TransitionContext ctx) sync* {
    var currentNode = parentNode;
    while (!currentNode.isLeaf) {
      final initialChildKey = parentNode.initialChild(ctx);
      if (initialChildKey == null) {
        throw StateError('initialChild for state ${parentNode.key} returned null');
      }
      final initialChild = nodes[initialChildKey];
      if (initialChild == null) {
        throw StateError('Unable to find initialChild $initialChildKey for state ${parentNode.key}.');
      }
      yield initialChild;
      currentNode = initialChild;
    }
  }

  // TODO: is it possible to return FutureOr?
  Future<void> _enterStates(Iterable<TreeNode> nodesToEnter, _TransitionContext transCtx) async {
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

class _TransitionContext extends TransitionContext {
  final List<TreeNode> _enteredNodes = [];
  final List<TreeNode> _exitedNodes = [];

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
