import 'dart:async';

import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class CurrentState {
  sendMessage(Object message) {}
}

class Transition {}

class TreeStateMachine {
  final TreeNode _rootNode;
  final Map<StateKey, TreeNode> _nodeMap;
  final StreamController<Transition> _transitions;
  Stream<Transition> _transitionsStream;
  bool _isStarted = false;
  CurrentState _currentState;

  TreeStateMachine._(this._rootNode, this._nodeMap, this._transitions) {
    _transitionsStream = _transitions.stream.asBroadcastStream();
  }

  factory TreeStateMachine.forRoot(BuildRoot buildRoot) {
    if (buildRoot == null) throw ArgumentError.notNull('buildRoot');

    var buildCtx = BuildContext(null);
    var rootNode = buildRoot(buildCtx);

    return TreeStateMachine._(rootNode, buildCtx.nodes, StreamController());
  }

  factory TreeStateMachine.forLeaves(Iterable<BuildLeaf> buildLeaves, StateKey initialState) {
    if (buildLeaves == null) throw ArgumentError.notNull('buildLeaves');
    if (initialState == null) throw ArgumentError.notNull('initialState');

    var rootBuilder = BuildRoot(
        state: () => _RootState(), children: buildLeaves, entryTransition: (_) => initialState);
    var buildCtx = BuildContext(null);
    var rootNode = rootBuilder(buildCtx);

    return TreeStateMachine._(rootNode, buildCtx.nodes, StreamController());
  }

  bool get isStarted => _isStarted;
  CurrentState get currentState => _currentState;
  Stream<Transition> get transitions => _transitionsStream;

  void start([StateKey initialStateKey]) {
    if (initialStateKey == null) throw ArgumentError.notNull('initialStateKey');
    if (_isStarted) throw StateError('This TreeStateMachine has already been started.');

    var initialNode = initialStateKey != null ? _nodeMap[initialStateKey] : _rootNode;
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
  final TreeNode rootNode;
  final Map<StateKey, TreeNode> nodes;
  _Machine(this.rootNode, this.nodes);

  Future<void> enterInitialState(TreeNode initialNode) async {
    var transCtx = TransitionContext();

    // States along the path from the root state to the requested initial state.
    var rootToInitialLeaf = initialNode.ancestors().toList().reversed;

    // If the initial state is not a leaf, we need to follow the initialChild of each descendant,
    // until we reach a leaf.
    if (!initialNode.isLeaf) {
      rootToInitialLeaf =
          rootToInitialLeaf.followedBy(_descendInitialChildren(initialNode, transCtx));
    }

    await _enterStates(rootToInitialLeaf, transCtx);
  }

  Iterable<TreeNode> _descendInitialChildren(TreeNode parentNode, TransitionContext ctx) sync* {
    while (!parentNode.isLeaf) {
      var initialChildKey = parentNode.initialChild(ctx);
      if (initialChildKey == null) {
        throw StateError('initialChild for state ${parentNode.key} returned null');
      }
      var initialChild = nodes[initialChildKey];
      if (initialChild == null) {
        throw StateError(
            'Unable to find initialChild ${initialChildKey} for state ${parentNode.key}.');
      }
      yield initialChild;
      parentNode = initialChild;
    }
  }

  Future<void> _enterStates(Iterable<TreeNode> nodesToEnter, TransitionContext transCtx) async {
    for (var node in nodesToEnter) {
      await node.handler().onEnter(transCtx);
    }
  }

  Future<void> _exitStates(Iterable<TreeNode> nodesToEnter, TransitionContext transCtx) async {
    for (var node in nodesToEnter) {
      await node.handler().onExit(transCtx);
    }
  }
}

// Root state for wrapping 'flat' leaf states.
class _RootState extends EmptyTreeState {}
