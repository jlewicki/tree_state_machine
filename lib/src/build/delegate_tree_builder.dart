import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'tree_builder.dart';
import 'tree_node_info.dart';

class StateTree implements StateTreeBuildProvider {
  StateTree._(this.info);

  factory StateTree(
    StateKey rootKey, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<State> children,
    required InitialChild initialChild,
  }) {
    RootNodeInfo? root;
    root = RootNodeInfo(
      rootKey,
      (_) => DelegatingTreeState(
        onMessage ?? emptyMessageHandler,
        onEnter ?? emptyTransitionHandler,
        onEnter ?? emptyTransitionHandler,
      ),
      children: children.map((e) => e._toNodeInfo(root!)).toList(),
      initialChild: initialChild.call,
    );
    return StateTree._(root);
  }

  final RootNodeInfo info;

  @override
  RootNodeInfo createRootNodeInfo() => info;
}

class State {
  State._(this.key,
      {this.onEnter,
      this.onExit,
      this.onMessage,
      this.children = const [],
      this.initialChild,
      this.isFinal = false});

  factory State.leaf(
    StateKey key, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    bool isFinal = false,
  }) {
    return State._(key,
        onEnter: onEnter,
        onExit: onExit,
        onMessage: onMessage,
        isFinal: isFinal);
  }

  factory State.interior(
    StateKey key, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<State> children,
    required InitialChild initialChild,
  }) {
    return State._(key,
        onEnter: onEnter,
        onExit: onExit,
        onMessage: onMessage,
        children: children,
        initialChild: initialChild);
  }

  final StateKey key;
  final TransitionHandler? onEnter;
  final TransitionHandler? onExit;
  final MessageHandler? onMessage;
  final List<State> children;
  final bool isFinal;
  final InitialChild? initialChild;

  TreeNodeInfo _toNodeInfo(TreeNodeInfo parent) {
    assert(children.isEmpty || initialChild != null);

    var treeState = DelegatingTreeState(
      onMessage ?? emptyMessageHandler,
      onEnter ?? emptyTransitionHandler,
      onEnter ?? emptyTransitionHandler,
    );

    TreeNodeInfo? nodeInfo;
    nodeInfo = children.isEmpty
        ? LeafNodeInfo(
            key,
            (_) => treeState,
            parent: parent,
            isFinalState: isFinal,
          )
        : InteriorNodeInfo(
            key,
            (_) => treeState,
            parent: parent,
            children: children.map((e) => e._toNodeInfo(nodeInfo!)).toList(),
            initialChild: initialChild!.call,
          );

    return nodeInfo;
  }
}
