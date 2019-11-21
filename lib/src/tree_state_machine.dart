import 'dart:async';

import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class CurrentState {
  void sendMessage(Object message) {}
}

class Transition {}

class TreeStateMachine {
  TreeStateMachine._(this._rootNode, this._nodeMap, this._transitions) {
    _transitionsStream = _transitions.stream.asBroadcastStream();
  }

  factory TreeStateMachine.forRoot(BuildRoot buildRoot) {
    if (buildRoot == null) {
      throw ArgumentError.notNull('buildRoot');
    }

    final buildCtx = BuildContext(null);
    final rootNode = buildRoot(buildCtx);

    return TreeStateMachine._(rootNode, buildCtx.nodes, StreamController());
  }

  factory TreeStateMachine.forLeaves(Iterable<BuildLeaf> buildLeaves, StateKey initialState) {
    if (buildLeaves == null) {
      throw ArgumentError.notNull('buildLeaves');
    }
    if (initialState == null) {
      throw ArgumentError.notNull('initialState');
    }

    final rootBuilder = BuildRoot(
      state: () => _RootState(),
      children: buildLeaves,
      entryTransition: (_) => initialState,
    );
    final buildCtx = BuildContext(null);
    final rootNode = rootBuilder(buildCtx);

    return TreeStateMachine._(rootNode, buildCtx.nodes, StreamController());
  }

  final TreeNode _rootNode;
  final Map<StateKey, TreeNode> _nodeMap;
  final StreamController<Transition> _transitions;
  Stream<Transition> _transitionsStream;
  bool _isStarted = false;
  CurrentState _currentState;

  bool get isStarted => _isStarted;
  CurrentState get currentState => _currentState;
  Stream<Transition> get transitions => _transitionsStream;

  void start([StateKey initialStateKey]) {
    if (initialStateKey == null) {
      throw ArgumentError.notNull('initialStateKey');
    }
    if (_isStarted) {
      throw StateError('This TreeStateMachine has already been started.');
    }

    final initialNode = initialStateKey != null ? _nodeMap[initialStateKey] : _rootNode;
    if (initialNode == null) {
      throw ArgumentError.value(
        initialStateKey,
        'initalStateKey',
        'This TreeStateMachine does not contain the specified initial state.',
      );
    }

    _isStarted = true;
  }
}

// Core state machine operations
class _Machine {
  _Machine(this.rootNode, this.nodes);

  final TreeNode rootNode;
  final Map<StateKey, TreeNode> nodes;

  Future<TransitionContext> enterInitialState(TreeNode initialNode) async {
    final transCtx = TransitionContext();

    // States along the path from the root state to the requested initial state.
    var entryPath = initialNode.ancestors().toList().reversed;

    // If the initial state is not a leaf, we need to follow the initialChild of each descendant,
    // until we reach a leaf.
    if (!initialNode.isLeaf) {
      entryPath = entryPath.followedBy(_descendInitialChildren(initialNode, transCtx));
    }

    await _enterStates(entryPath, transCtx);

    return transCtx;
  }

  Iterable<TreeNode> _descendInitialChildren(TreeNode parentNode, TransitionContext ctx) sync* {
    var currentNode = parentNode;
    while (!currentNode.isLeaf) {
      final initialChildKey = parentNode.initialChild(ctx);
      if (initialChildKey == null) {
        throw StateError('initialChild for state ${parentNode.key} returned null');
      }
      final initialChild = nodes[initialChildKey];
      if (initialChild == null) {
        throw StateError(
            'Unable to find initialChild $initialChildKey for state ${parentNode.key}.');
      }
      yield initialChild;
      currentNode = initialChild;
    }
  }

  Future<void> _enterStates(Iterable<TreeNode> nodesToEnter, TransitionContext transCtx) async {
    for (final node in nodesToEnter) {
      // var result = node.handler().onEnter(transCtx);
      // if (result is )

      await node.handler().onEnter(transCtx);
    }
  }

  Future<void> _exitStates(Iterable<TreeNode> nodesToEnter, TransitionContext transCtx) async {
    for (final node in nodesToEnter) {
      await node.handler().onExit(transCtx);
    }
  }
}

// Root state for wrapping 'flat' leaf states.
class _RootState extends EmptyTreeState {}
