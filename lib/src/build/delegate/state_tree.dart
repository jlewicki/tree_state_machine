import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// The construction protocol for tree states.
abstract interface class StateConfig {
  /// Constructs a [TreeNodeInfo] representing the tree state, with the specified [parent] node.
  TreeNodeInfo nodeInfo(TreeNodeInfo parent);
}

/// The construction protocol for final tree states.
abstract interface class FinalStateConfig {
  /// Constructs a [TreeNodeInfo] representing the final tree state, with the specified [parent]
  /// node.
  TreeNodeInfo nodeInfo(TreeNodeInfo parent);
}

/// The key identifying the root state that is implicitly added to a state tree when using the
/// [StateTree.new] constructor.
const StateKey defaultRootKey = StateKey('<!StateTree.RootState!>');

/// Defines a state tree that can be used in conjunction with a [TreeStateMachine].
class StateTree implements StateTreeBuildProvider {
  StateTree._(this._info);

  /// Constructs a state tree that is is composed of the states in the list of [childStates], and
  /// starts in the state identified by the [initialChild].
  ///
  /// The state tree has an implicit root state, identified by [defaultRootKey]. This state has no
  /// associated behavior, and it is typically safe to ignore its presence.
  ///
  /// {@template StateTree.finalStates}
  /// A list of [finalStates] can be provided. Final states are children of the root state, and if a
  /// final state is entered, further message processing or state transitions will not occur, and
  /// the state tree can be considered complete.
  /// {@endtemplate}
  factory StateTree(
    InitialChild initialChild, {
    required List<StateConfig> childStates,
    List<FinalStateConfig> finalStates = const [],
  }) {
    return StateTree._(_createRoot(
      defaultRootKey,
      (_) => DelegatingTreeState(),
      initialChild,
      childStates,
      finalStates,
      null,
      null,
    ));
  }

  /// Constructs a state tree with a root state identified by [rootKey].
  ///
  /// {@template StateTree.children}
  /// The state tree is composed of the states in the list of [childStates], and
  /// starts in the state identified by the [initialChild].
  /// {@endtemplate}
  ///
  /// {@template StateTree.handlers}
  /// The behavior of the root state can be customized by providing [onMessage],
  /// [onEnter], and [onExit] handler functions.
  /// {@endtemplate}
  ///
  /// {@macro StateTree.finalStates}
  ///
  /// {@template StateTree.filters}
  /// A list of [filters] can be provided in order to intercept the message and
  /// transition handlers of the root state. The filters will be applied to the
  /// state in the order in which they appear in the list.
  /// {@endtemplate}
  factory StateTree.root(
    StateKey rootKey,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> childStates,
    List<FinalStateConfig> finalStates = const [],
    List<TreeStateFilter>? filters,
  }) {
    return StateTree._(_createRoot(
      rootKey,
      (_) => DelegatingTreeState(
        onMessage: onMessage,
        onEnter: onEnter,
        onExit: onExit,
      ),
      initialChild,
      childStates,
      finalStates,
      null,
      filters,
    ));
  }

  /// Constructs a state tree with a root data state identified by [rootKey], starting with a state
  /// data value provided by [initialData].
  ///
  /// {@macro StateTree.children}
  ///
  /// {@macro StateTree.handlers}
  ///
  /// {@macro StateTree.finalStates}
  ///
  /// {@macro StateTree.filters}
  static StateTree dataRoot<D>(
    DataStateKey<D> rootKey,
    InitialData<D> initialData,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> childStates,
    List<FinalStateConfig> finalStates = const [],
    StateDataCodec<D>? codec,
    List<TreeStateFilter>? filters,
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
        childStates,
        finalStates,
        codec,
        filters));
  }

  final RootNodeInfo _info;

  @override
  RootNodeInfo createRootNodeInfo() => _info;

  static RootNodeInfo _createRoot(
    StateKey rootKey,
    StateCreator createState,
    InitialChild initialChild,
    List<StateConfig> children,
    List<FinalStateConfig> finalStates,
    StateDataCodec<dynamic>? codec,
    List<TreeStateFilter>? filters,
  ) {
    var childNodes = <TreeNodeInfo>[];
    var root = RootNodeInfo(
      rootKey,
      createState,
      children: childNodes,
      initialChild: initialChild.call,
      dataCodec: codec,
      filters: filters ?? const [],
    );

    childNodes.addAll(children
        .map((e) => e.nodeInfo(root))
        .followedBy(finalStates.map((e) => e.nodeInfo(root))));

    return root;
  }
}
