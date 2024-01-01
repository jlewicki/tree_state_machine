import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

class State implements StateConfig {
  State._(this._nodeInfo);

  /// Constructs a leaf state identified by [key].
  ///
  /// A leaf state does not contain any child states.
  ///
  /// {@template State.handlers}
  /// The behavior of the state can be customized by providing [onMessage], [onEnter], and [onExit]
  /// handler functions.
  /// {@endtemplate}
  factory State(
    StateKey key, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
  }) =>
      State._((parent) {
        return LeafNodeInfo(
          key,
          (_) => DelegatingTreeState(
            onMessage: onMessage,
            onEnter: onEnter,
            onExit: onExit,
          ),
          parent: parent,
          isFinalState: false,
        );
      });

  /// Constructs a composite state identified by [key].
  ///
  /// {@template State.childStates}
  /// A composite state contains a number of [childStates]. When the composite state is entered,
  /// [initialChild] will be used to determine which if the child states to enter.
  /// {@endtemplate}
  ///
  /// {@macro State.handlers}
  factory State.composite(
    StateKey key,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<State> childStates,
  }) =>
      State._((parent) {
        var childNodes = <TreeNodeInfo>[];
        var nodeInfo = InteriorNodeInfo(
          key,
          (_) => DelegatingTreeState(
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

/// A final state in a state tree.
///
/// {@template FinalState.finalState}
/// When a final state is entered, further message processing or state transitions will not occur, and
/// the state tree can be considered complete.
/// {@endtemplate}
class FinalState implements FinalStateConfig {
  FinalState._(this._nodeInfo);

  /// Constructs a final state, identified by [key].
  ///
  /// The behavior of the state when it is entered can be customized by providing an [onEnter]
  /// function.
  factory FinalState(
    StateKey key, {
    TransitionHandler? onEnter,
  }) =>
      FinalState._((parent) {
        return LeafNodeInfo(
          key,
          (_) => DelegatingTreeState(onEnter: onEnter),
          parent: parent,
          isFinalState: true,
        );
      });

  final TreeNodeInfo Function(TreeNodeInfo parent) _nodeInfo;

  @override
  TreeNodeInfo nodeInfo(TreeNodeInfo parent) => _nodeInfo(parent);
}
