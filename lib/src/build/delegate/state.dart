import 'dart:async';

import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

/// A state in a state tree.
///
/// The state can be a leaf or composite state, depending on which factory is
/// used to construct the state.
class State implements StateConfig {
  State._(this._nodeInfo);

  /// Constructs a leaf state identified by [key].
  ///
  /// A leaf state does not contain any child states.
  ///
  /// {@template State.handlers}
  /// The behavior of the state can be customized by providing [onMessage],
  /// [onEnter], and [onExit]
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
  /// A composite state contains a number of [childStates]. When the composite
  /// state is entered, [initialChild] will be used to determine which if the
  /// child states to enter.
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
/// When a final state is entered, further message processing or state
/// transitions will not occur, and the state tree can be considered complete.
/// {@endtemplate}
class FinalState implements FinalStateConfig {
  FinalState._(this._nodeInfo);

  /// Constructs a final state, identified by [key].
  ///
  /// The behavior of the state when it is entered can be customized by
  /// providing an [onEnter] function.
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

/// A machine state in a state tree.
///
/// A machine state has an accompanying nested state machine. When the state is
/// entered, it remains active as long as the nested state machine has not
/// completed (that is, until it reaches a final state, or is disposed).
///
/// Upon completion, the `onMachineDone` callback is called to determine the
/// next state to transition to.
///
class MachineState implements StateConfig {
  MachineState._(this._nodeInfo);

  /// Constructs a machine state, identified by [key].
  ///
  /// When this state is entered, [initialMachine] will be called to obtain the
  /// nested state machine for this state.
  ///
  /// The [onMachineDone] callback will be called when the nested state machine
  /// has finished, and the return value indicates which state to transition to
  /// now that that nested machine is done.
  ///
  /// If a [isMachineDone] callback is provided, it will be called for each
  /// transition that occurs within the nested state machine.  If the callback
  /// returns `true`, the state machine is considered 'done', even if the
  /// transition was not to a final state. This allows the [MachineState] to
  /// provide an early exit from the nested state machine if desired.
  ///
  /// If a [onMachineDisposed] callback is provided, it will be called if the
  /// nested state machine is disposed, and in a similar manner to
  /// [onMachineDone], the return value indicates which state to transition to
  /// now that the nested machine is disposed. Note that this will typically
  /// only be called if [initialMachine] returns an existing state machine, and
  /// that machine is disposed 'out of band' by the application.
  ///
  factory MachineState(
    DataStateKey<NestedMachineData> key,
    InitialMachine initialMachine, {
    required MachineDoneHandler onMachineDone,
    bool Function(Transition)? isMachineDone,
    MachineDisposedHandler? onMachineDisposed,
  }) =>
      MachineState._((parent) {
        return LeafNodeInfo(
          key,
          (_) => NestedMachineState(
            initialMachine,
            (currentMachineState) =>
                (msgCtx) => onMachineDone(msgCtx, currentMachineState),
            null, // Logger
            isMachineDone,
            onMachineDisposed,
          ),
          parent: parent,
          isFinalState: false,
        );
      });

  final TreeNodeInfo Function(TreeNodeInfo parent) _nodeInfo;

  @override
  TreeNodeInfo nodeInfo(TreeNodeInfo parent) => _nodeInfo(parent);
}

/// Type of function that is called when a nested state machine in a
/// [MachineState] completes.
///
/// The function is provided the [CurrentState] of the nested state machine
/// (which will refer to a final state in the nested machine), and a
/// [MessageContext] that should be used to produce the return value that
/// indicates which state to transition to now that the nested state machine has
/// completed.
typedef MachineDoneHandler = FutureOr<TransitionMessageResult> Function(
  MessageContext msgCtx,
  CurrentState currentMachineState,
);

/// Type of function that is called when the nested state machine in a
/// [MachineState] is disposed.
///
/// The function is provided a [MessageContext] that should be used to produce
/// the return value that indicates which state to transition to, now that the
/// nested state machine is disposed.
typedef MachineDisposedHandler = FutureOr<TransitionMessageResult> Function(
  MessageContext msgCtx,
);
