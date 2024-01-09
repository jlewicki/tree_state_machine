import 'dart:async';

import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
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
  ///
  /// {@template State.filters}
  /// A list of [filters] can be provided in order to intercept the message and
  /// transition handlers of the state. The filters will be applied to the
  /// state in the order in which they appear in the list.
  /// {@endtemplate}
  factory State(
    StateKey key, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    List<TreeStateFilter> filters = const [],
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
          filters: filters,
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
  ///
  /// {@macro State.filters}
  factory State.composite(
    StateKey key,
    InitialChild initialChild, {
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
    MessageHandler? onMessage,
    required List<StateConfig> childStates,
    List<TreeStateFilter> filters = const [],
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
          filters: filters,
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
class MachineState implements StateConfig {
  MachineState._(this._nodeInfo);

  /// Constructs a machine state, identified by [key].
  ///
  /// When this state is entered, a nested state machine that is produced by
  /// [initialMachine] will be started. By default any messages dispatched to
  /// this state will forwarded to the nested state machine for processing
  ///
  /// No transitions from this state will occur until the nested state machine
  /// reaches a completion state. By default, any final state is considered a
  /// completion state, but non-final states can also be completion states by
  /// providing an [isMachineDone] callback. This function will be called for
  /// each transition to a non-final state in the nested machine, and if `true`
  /// is returned, the nested state machine will be considered to have completed.
  ///
  /// If a [onMachineDisposed] callback is provided, it will be called if the
  /// nested state machine is disposed, and in a similar manner to
  /// [onMachineDone], the return value indicates which state to transition to
  /// now that the nested machine is disposed. Note that this will typically
  /// only be called if [initialMachine] returns an existing state machine, and
  /// that machine is disposed 'out of band' by the application.

  /// The machine state carries a state data value of [MachineTreeStateData].
  /// This value can be obtained in the same ways as other state data, for
  /// example using [CurrentState.dataValue].
  ///
  /// A machine state is always a leaf state. It can be declared as a child
  /// state, however all messages will be handled by the machine state until
  /// the nested state machine has completed, and as such the parent state will
  /// not recieve any unhandled messages from the child machine state.
  ///
  factory MachineState(
    MachineStateKey key,
    InitialMachine initialMachine, {
    required MachineDoneHandler onMachineDone,
    bool Function(Transition)? isMachineDone,
    MachineDisposedHandler? onMachineDisposed,
  }) =>
      MachineState._((parent) {
        return LeafNodeInfo(
          key,
          (_) => MachineTreeState(
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
