import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

sealed class StateConfig {
  TreeNodeInfo nodeInfo(TreeNodeInfo parent);
}

/// The key identifying the root state that is implicitly added to a state tree when using the
/// [StateTree.new] constructor.
const StateKey defaultRootKey = StateKey('<!StateTree.RootState!>');

/// Defines a state tree that can be used in conjunction with a [TreeStateMachine].
class StateTree implements StateTreeBuildProvider {
  StateTree._(this._info);

  /// Constructs a state tree that is is composed of the states in the list of [children], and
  /// starts in the state identified by the [initialChild].
  ///
  /// The state tree has an implicit root state, identified by [defaultRootKey]. This state has no
  /// associated behavior, and it is typically safe to ignore its presence.
  factory StateTree(
    InitialChild initialChild, {
    required List<StateConfig> children,
  }) {
    return StateTree._(_createRoot(
      defaultRootKey,
      (_) => DelegatingTreeState(),
      initialChild,
      children,
    ));
  }

  /// Constructs a state tree with a root state identified by [rootKey].
  ///
  /// The state tree is composed of the states in the list of [children], and starts in the state
  /// identified by the [initialChild].
  ///
  /// The behavior of the root state can be specified by providing [onMessage], [onEnter], and
  /// [onExit] hander functions.
  factory StateTree.root(
    StateKey rootKey,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> children,
  }) {
    return StateTree._(_createRoot(
      rootKey,
      (_) => DelegatingTreeState(
        onMessage: onMessage,
        onEnter: onEnter,
        onExit: onExit,
      ),
      initialChild,
      children,
    ));
  }

  static StateTree dataRoot<D>(
    StateKey rootKey,
    InitialData<D> initialData, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> children,
    required InitialChild initialChild,
  }) {
    return StateTree._(_createRoot(
      rootKey,
      (_) => DelegatingDataTreeState<D>(
        initialData.call,
        onMessage: onMessage,
        onEnter: onEnter,
        onExit: onExit,
      ),
      initialChild,
      children,
    ));
  }

  final RootNodeInfo _info;

  @override
  RootNodeInfo createRootNodeInfo() => _info;

  static RootNodeInfo _createRoot(
    StateKey rootKey,
    StateCreator createState,
    InitialChild initialChild,
    List<StateConfig> children,
  ) {
    var childNodes = <TreeNodeInfo>[];
    var root = RootNodeInfo(
      rootKey,
      createState,
      children: childNodes,
      initialChild: initialChild.call,
    );

    childNodes.addAll(children.map((e) => e.nodeInfo(root)));

    return root;
  }
}

class State extends StateConfig {
  State._(this.key,
      {this.onEnter,
      this.onExit,
      this.onMessage,
      this.children = const [],
      this.initialChild,
      this.isFinal = false});

  factory State(
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

  factory State.composite(
    StateKey key,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<State> children,
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
      onMessage: onMessage,
      onEnter: onEnter,
      onExit: onExit,
    );

    var childNodes = <TreeNodeInfo>[];
    var nodeInfo = children.isEmpty
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
            children: childNodes,
            initialChild: initialChild!.call,
          );

    childNodes.addAll(children.map((e) => e.nodeInfo(nodeInfo)));

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

  factory DataState(
    DataStateKey<D> key,
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

  factory DataState.composite(
    DataStateKey<D> key,
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

  final DataStateKey<D> key;
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

    var childNodes = <TreeNodeInfo>[];
    var nodeInfo = children.isEmpty
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
            children: childNodes,
            initialChild: initialChild!.call,
          );

    childNodes.addAll(children.map((e) => e.nodeInfo(nodeInfo)));

    return nodeInfo;
  }
}
