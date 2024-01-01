import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// A data state with associated state data of type [D].
class DataState<D> implements StateConfig {
  DataState._(this._nodeInfo);

  /// Constructs a leaf data state identified by [key], with associated state data of type [D].
  ///
  /// A leaf state does not contain any child states.
  ///
  /// {@template DataState.initialData}
  /// When the data state is entered, [initialData] will be used to determine the initial value
  /// for the associated state data.
  /// {@endtemplate}
  ///
  /// {@macro State.handlers}
  factory DataState(
    DataStateKey<D> key,
    InitialData<D> initialData, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
  }) =>
      DataState._((parent) {
        return LeafNodeInfo(
          key,
          (_) => DelegatingDataTreeState<D>(
            initialData.call,
            onMessage: onMessage,
            onEnter: onEnter,
            onExit: onExit,
          ),
          parent: parent,
          isFinalState: false,
        );
      });

  /// Constructs a composite data state identified by [key], with associated state data of type [D].
  ///
  /// {@macro DataState.initialData}
  ///
  /// {@macro State.childStates}
  ///
  /// {@macro State.handlers}
  factory DataState.composite(
    DataStateKey<D> key,
    InitialData<D> initialData,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<State> childStates,
  }) =>
      DataState._((parent) {
        var childNodes = <TreeNodeInfo>[];
        var nodeInfo = InteriorNodeInfo(
          key,
          (_) => DelegatingDataTreeState<D>(
            initialData.call,
            onMessage: onMessage,
            onEnter: onEnter,
            onExit: onExit,
          ),
          parent: parent,
          initialChild: initialChild.call,
          children: childNodes,
        );

        childNodes.addAll(childStates.map((e) => e.nodeInfo(nodeInfo)));

        return nodeInfo;
      });

  final TreeNodeInfo Function(TreeNodeInfo parent) _nodeInfo;

  @override
  TreeNodeInfo nodeInfo(TreeNodeInfo parent) => _nodeInfo(parent);
}

/// A final data state in a state tree, with associated state data of type [D].
///
/// {@macro FinalState.finalState}
class FinalDataState<D> implements FinalStateConfig {
  FinalDataState._(this._nodeInfo);

  final TreeNodeInfo Function(TreeNodeInfo parent) _nodeInfo;

  /// Constructs a final data state, identified by [key].
  ///
  /// {@macro DataState.initialData}
  ///
  /// The behavior of the state when it is entered can be customized by providing an [onEnter]
  /// function.
  factory FinalDataState(
    DataStateKey<D> key,
    InitialData<D> initialData, {
    TransitionHandler? onEnter,
  }) =>
      FinalDataState._((parent) {
        return LeafNodeInfo(
          key,
          (_) => DelegatingDataTreeState<D>(initialData.call, onEnter: onEnter),
          parent: parent,
          isFinalState: true,
        );
      });

  @override
  TreeNodeInfo nodeInfo(TreeNodeInfo parent) => _nodeInfo(parent);
}
