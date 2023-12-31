import 'package:tree_state_machine/src/machine/tree_state.dart';
import '../tree_builder.dart';
import '../tree_node_info.dart';

sealed class StateConfig {
  TreeNodeInfo nodeInfo(TreeNodeInfo parent);
}

class StateTree implements StateTreeBuildProvider {
  StateTree._(this.info);

  factory StateTree(
    StateKey rootKey, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> children,
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
      children: children.map((e) => e.nodeInfo(root!)).toList(),
      initialChild: initialChild.call,
    );
    return StateTree._(root);
  }

  final RootNodeInfo info;

  @override
  RootNodeInfo createRootNodeInfo() => info;
}

class State extends StateConfig {
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
  final List<StateConfig> children;
  final bool isFinal;
  final InitialChild? initialChild;

  @override
  TreeNodeInfo nodeInfo(TreeNodeInfo parent) {
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
            children: children.map((e) => e.nodeInfo(nodeInfo!)).toList(),
            initialChild: initialChild!.call,
          );

    return nodeInfo;
  }
}

class DataState<D> extends StateConfig {
  DataState._(
    this.key,
    this.initialData, {
    this.onEnter,
    this.onExit,
    this.onMessage,
    this.children = const [],
    this.initialChild,
    this.isFinal = false,
  });

  factory DataState.leaf(
    StateKey key,
    InitialData<D> initialData, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    bool isFinal = false,
  }) {
    return DataState._(
      key,
      initialData,
      onEnter: onEnter,
      onExit: onExit,
      onMessage: onMessage,
      isFinal: isFinal,
    );
  }

  factory DataState.interior(
    StateKey key,
    InitialData<D> initialData, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> children,
    required InitialChild initialChild,
  }) {
    return DataState._(
      key,
      initialData,
      onEnter: onEnter,
      onExit: onExit,
      onMessage: onMessage,
      children: children,
      initialChild: initialChild,
    );
  }

  final StateKey key;
  final TransitionHandler? onEnter;
  final TransitionHandler? onExit;
  final MessageHandler? onMessage;
  final List<StateConfig> children;
  final bool isFinal;
  final InitialChild? initialChild;
  final InitialData<D> initialData;

  @override
  TreeNodeInfo nodeInfo(TreeNodeInfo parent) {
    assert(children.isEmpty || initialChild != null);

    var treeState = DelegatingDataTreeState<D>(
      initialData.call,
      onMessage: onMessage,
      onEnter: onEnter,
      onExit: onExit,
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
            children: children.map((e) => e.nodeInfo(nodeInfo!)).toList(),
            initialChild: initialChild!.call,
          );

    return nodeInfo;
  }
}
