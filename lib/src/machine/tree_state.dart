import 'dart:async';

import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

//==================================================================================================
//
// Keys
//

/// A [StateKey] is an indentifier for a state within a tree state machine.
///
/// Keys must be unique within a tree of states.
abstract class StateKey {
  const StateKey._();

  /// Construct a [StateKey] with the specifed name.
  ///
  /// The name must be unique within a state tree.
  const factory StateKey(String name) = _ValueKey<String>;

  /// Construct a [StateKey] with the specifed name.
  ///
  /// The name must be unique within a state tree.
  const factory StateKey.named(String name) = _ValueKey<String>;

  /// Construct a [StateKey] with a name based on the specified state type.
  ///
  /// This may be useful if each state in a tree is represented by its own [TreeState] subclass, and
  /// therefore a unique name for the state can be inferred from the type name.
  static StateKey forState<T extends TreeState>() => _ValueKey<Type>(TypeLiteral<T>().type);
}

@immutable
class _ValueKey<T> extends StateKey {
  final T value;
  const _ValueKey(this.value) : super._();

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    final typedOther = other as _ValueKey<T>;
    return value == typedOther.value;
  }

  @override
  int get hashCode {
    var hash = 7;
    hash = 31 * hash + runtimeType.hashCode;
    hash = 31 * hash + value.hashCode;
    return hash;
  }

  @override
  String toString() => '$value';
}

/// Identifies the stopped state in a state tree.
final stoppedStateKey = StateKey('!Stopped!');

//==================================================================================================
//
// States
//

/// Type of functions that create a new [TreeState].
///
/// The function is passed the [StateKey] that identifies the new state.
typedef StateCreator = TreeState Function(StateKey key);

/// Type of functions that are called when a state transition occurs within a state machine.
///
/// Each state in the state machine has two associated [TransitionHandler]s. One is called by the
/// state machine each time the state is entered, and the other is called each time the state is
/// exited.
typedef TransitionHandler = FutureOr<void> Function(TransitionContext ctx);

/// Type of functions that process messages sent to a state machine.
///
/// Each state in the state machine has an associated [MessageHandler], and the state machine calls
/// this handler when the state is active and a message is sent to the machine.
///
/// The handler accepts a [MessageContext] describing the message that was sent, and returns
/// (possibly asynchronously) a [MessageResult] describing how the state processed the message. The
/// [MessageResult] is created by calling methods on the [MessageContext], such as
/// [MessageContext.goTo].
typedef MessageHandler = FutureOr<MessageResult> Function(MessageContext ctx);

/// A [TransitionHandler] that returns immediately.
FutureOr<void> emptyTransitionHandler(TransitionContext transCtx) {}

/// A [MessageHandler] that always returns [MessageContext.unhandled].
FutureOr<MessageResult> emptyMessageHandler(MessageContext msgCtx) => msgCtx.unhandled();

/// Type of functions that select a child state to initially enter, when a parent state is entered.
///
/// The function is passed a [TransitionContext] that describes the transition that is currently
/// taking place.
typedef GetInitialChild = StateKey Function(TransitionContext ctx);

/// An individual state within a tree state machine.
///
/// A tree state is defined by its behavior in response to messages, represented by the [onMessage]
/// override. This method is called when the state is an active state within a state machine and a
/// message is sent to the machine for processing. The [onMessage] override returns a
/// [MessageResult] indicating if the message was handled, and if a state transition should occur.
///
/// In addition, [onEnter] and [onExit] can be overriden to perform initialization or establish
/// invariants that must hold while the state is active.
class TreeState {
  /// Processes a message that has been sent to this state.
  ///
  /// The [MessageContext] argument describes the message that was sent. Subclasses can inspect this
  /// message and trigger state transitions by calling various methods on this context, such as
  /// [MessageContext.goTo].
  ///
  /// If the state does not recognize the message, it can call [MessageContext.unhandled]. The state
  /// machine will then call [onMessage] on the parent state of this state, giving it an opportunity
  /// to handle the message.
  final MessageHandler onMessage;

  /// Called when this state is being entered during a state transition.
  ///
  /// Note that this method should be idempotent. It is possible, if unlikely, that when recovering
  /// from an error condition this method might be called more than once without a corresponding
  /// call to [onExit].
  final TransitionHandler onEnter;

  /// Called when this state is being exited during a state transition.
  ///
  /// Subclasses can overide to dispose of resources or execute cleanup logic.
  ///
  /// Note that this method should be idempotent. It is possible, if unlikely, that when recovering
  /// from an error condition this method might be called more than once without a corresponding
  /// call to [onEnter].
  final TransitionHandler onExit;

  final Dispose? onDispose;

  /// Constructs a [TreeState] instance.
  TreeState(
      this.onMessage, TransitionHandler? onEnter, TransitionHandler? onExit, Dispose? onDispose)
      : onEnter = onEnter ?? emptyTransitionAction,
        onExit = onExit ?? emptyTransitionAction,
        onDispose = onDispose ?? emptyDispose;
}

/// A tree state with an associated data value of type `D`.
///
/// The [data] property provides access to a [DataValue] that encapsulates to the current state
/// data, as well as providing change notifications in the form of a [Stream]. This [DataValue]
/// is recreated each time she state is entered.
class DataTreeState<D> extends TreeState {
  Ref<ClosableDataValue<D>?> _refDataValue;

  /// The data value associated with this state. Returns `null` when the state is not active.
  DataValue<D>? get data => _refDataValue.value;

  DataTreeState._(
    this._refDataValue,
    MessageHandler onMessage,
    TransitionHandler onEnter,
    TransitionHandler onExit,
    Dispose onDispose,
  ) : super(onMessage, onEnter, onExit, onDispose);

  factory DataTreeState(
    InitialData<D> initialData,
    MessageHandler onMessage,
    TransitionHandler? onEnter,
    TransitionHandler? onExit,
  ) {
    var refDataValue = Ref<ClosableDataValue<D>?>(null);

    FutureOr<void> _onEnter(TransitionContext transCtx) {
      assert(refDataValue.value == null);
      var initialValue = initialData.eval(transCtx);
      refDataValue.value = ClosableDataValue(initialValue);
      if (onEnter != null) onEnter(transCtx);
    }

    FutureOr<void> _onExit(TransitionContext transCtx) {
      if (onExit != null) onExit(transCtx);
      assert(refDataValue.value != null);
      refDataValue.value?.close();
      refDataValue.value = null;
    }

    void _onDispose() {
      refDataValue.value?.close();
    }

    return DataTreeState._(refDataValue, onMessage, _onEnter, _onExit, _onDispose);
  }

  void setValue(Object o) {
    if (_refDataValue.value == null) {
      throw StateError('DataValue has not been created because state has not yet been entered.');
    }
    _refDataValue.value!.setValue(o);
  }
}

//==================================================================================================
//
// Messages
//

/// Type of functions that are used to signal that resources can be released.
typedef Dispose = void Function();

/// Provides information to a state about the message that is being processed.
///
/// This context is provided as an argument to [TreeState.onMessage]. In addition to providing
/// access to the [message] that is being processed, it has several methods that allow a message
/// handler to indicate the result its processsing. For example, the handler can indicate that a
/// state transition should occur by calling [goTo], or that message processing should be delegated
/// to its parent state by calling [unhandled].
abstract class MessageContext {
  /// The message that is being processed by the state machine.
  Object get message;

  /// A map for storing application data.
  ///
  /// This map may be useful for storing application-specific values that might need to shared across
  /// various message handlers as a message is processed. This map will never be read or modified by
  /// the state machine.
  Map<String, Object> get appData;

  /// Returns a [MessageResult] indicating that a transition to the specified state should occur.
  ///
  /// A `transitionAction` may optionally be specified. This function that will be called during the
  /// transition between states, after all states are exited, but before entering any new states.
  ///
  /// A `payload` may be optionally specified. This payload will be made available by
  /// [TransitionContext.payload] to the states that are exited and entered during the state
  /// transition, and can be used to provide additional application specific context describing
  /// the transition.
  ///
  /// A `reenterTarget` flag may be optionally specified. If `true`, and the target state an active
  /// state, then the target state will be exited and entered, calling [TreeState.onExit] and
  /// [TreeState.onEnter], during the transition.
  MessageResult goTo(
    StateKey targetStateKey, {
    TransitionHandler? transitionAction,
    Object? payload,
    bool reenterTarget = false,
  });

  /// Returns a [MessageResult] indicating that an internal transition should occur.
  ///
  /// An internal transition means that the current state will not change, and no entry and exit
  /// handlers will be called.
  MessageResult stay();

  /// Returns a [MessageResult] indicating that a self-transition should occur.
  ///
  /// A self-transition means that the state that calls this method is exited and re-entered,
  /// calling the handler functions for the state.
  ///
  /// If the calling state is a leaf state, only that state is re-entered. If the calling state is
  /// an interior state, all the states from the current leaf state to the calling interior state
  /// are re-entered.
  MessageResult goToSelf({TransitionHandler? transitionAction});

  /// Returns a [MessageResult] indicating the message could not be handled by a state, and that
  /// its parent state should be given an opportunity to handle the message.
  MessageResult unhandled();

  /// Posts a message that should be dispatched to the state machine asynchronously.
  void post(FutureOr<Object> message);

  ///
  DataValue<D>? data<D>([StateKey? key]);

  /// Schedules a message to be dispatched to the state machine asynchronously.
  ///
  /// The time at which the message is sent is indicated by the [duration] argument. If not
  /// specified, it will be sent as soon as possible (but still asynchronously).
  ///
  /// If [periodic] is true, then messages will be dispatched repeatedly, at intervals specified by
  /// [duration]. Note that a [Timer] is used in the underlying implemention. Refer to
  /// [Timer.periodic(duration, callback)] for further details regarding scheduling.
  ///
  /// This scheduling is only valid while the state that calls this method is active. If a state
  /// transition occurs and the state is exited, the scheduling is automatically cancelled.
  ///
  /// The returned [Dispose] can be used to cancel the scheduled messaging (periodic or
  /// otherwise).
  Dispose schedule(
    Object Function() message, {
    Duration duration = const Duration(),
    bool periodic = false,
  });
}

/// Type of functions that can apply side-effects as transitions occcur.
typedef TransitionAction = FutureOr<void> Function(TransitionContext ctx);

/// A transition action that does nothing.
FutureOr<void> emptyTransitionAction(TransitionContext ctx) {}

/// A dispose function that does nothing
void emptyDispose() {}

/// Base class for describing the results of processing a state machine message.
///
/// Instances of this class are created by calling methods on [MessageContext], for example
/// [MessageContext.goTo].
abstract class MessageResult {
  MessageResult._();
}

/// A [MessageResult] indicating that a message was sucessfully handled, and a transition to a new
/// state should occur.
class GoToResult extends MessageResult {
  /// Indicates the state to which the state machine should transition.
  final StateKey targetStateKey;
  final TransitionAction? transitionAction;
  final Object? payload;
  final bool reenterTarget;
  GoToResult(this.targetStateKey,
      [this.transitionAction = emptyTransitionAction, this.payload, this.reenterTarget = false])
      : super._();
}

/// A [MessageResult] indicating that a message was successfully handled, and an internal transition
/// should occur. That is, the current state should remain the same.
class InternalTransitionResult extends MessageResult {
  InternalTransitionResult._() : super._();
  static final InternalTransitionResult value = InternalTransitionResult._();
}

/// A [MessageResult] indicating that a message was sucessfully handled, and an self transition
/// should occur. That is, the current state should remain the same, but the exit and entry handlers
/// for the state should be called.
class SelfTransitionResult extends MessageResult {
  final TransitionAction? transitionAction;
  SelfTransitionResult([this.transitionAction = emptyTransitionAction]) : super._();
}

/// A [MessageResult] indicating that a state machine is being stopped by application code.
class StopResult extends MessageResult {
  StopResult._() : super._();
  static final StopResult value = StopResult._();
}

/// A [MessageResult] indicating that a state did not recognize or handle a message.
class UnhandledResult extends MessageResult {
  UnhandledResult._() : super._();
  static final UnhandledResult value = UnhandledResult._();
}

//==================================================================================================
//
// Transitions
//

/// Describes a transition between states that is occuring in a tree state machine.
abstract class TransitionContext {
  /// The path of states describing the transition path that was requested.
  ///
  /// If the [Transition.to] state of this path is a non-leaf state, then the final state after
  /// the transition has completed will be a descendant state of the the [Transition.to] state.
  Transition get requestedTransition;

  Iterable<StateKey> get entered;

  Iterable<StateKey> get exited;

  StateKey get lca;

  /// The optional payload for this transition.
  ///
  /// When a state transition is initiated with [MessageContext.goTo], the caller may provide an
  /// optional payload value that provides further context for the transition to the target state.
  /// This property makes this payload accessible during the transition.
  Object? get payload;

  DataValue<D>? data<D>([StateKey? key]);

  /// Posts a message that should be sent to the end state of this transition, after the transition
  /// has completed.
  void post(FutureOr<Object> message);

  /// Schedules a message to be dispatched to the state machine asynchronously.
  ///
  /// The time at which the message is sent is indicated by the [duration] argument. If not
  /// specified, it will be sent as soon as possible (but still asynchronously).  If [schedule] is
  /// called when entering a state, the state (and any of its descendants) will be fully entered
  /// before the message is processed.
  ///
  /// If [periodic] is true, then messages will be dispatched repeatedly, at intervals specified by
  /// [duration]. Note that a [Timer] is used in the underlying implemention. Refer to
  /// [Timer.periodic(duration, callback)] for further details regarding scheduling.
  ///
  /// This scheduling is only valid while the state that calls this method is active. If a state
  /// transition occurs and the state is exited, the scheduling is automatically cancelled.
  /// Therefore it is typically only meaningful to schedule a message when entering a state, not
  /// when exiting.
  ///
  /// The returned [Dispose] can be used to cancel the scheduled messaging (periodic or
  /// otherwise).
  Dispose schedule(
    Object Function() message, {
    Duration duration = const Duration(),
    bool periodic = false,
  });
}

// /// Describes a path between two states in a state tree.
// ///
// /// Note that a given [TransitionPath] does not necessarily imply that the transition has occured. It
// /// typically describe a transition that will occur. Instead, [TransitionContext] describes the
// /// progress of a transition along this path, and [Transition] describes a completed transition.
// class TransitionPath {
//   /// The starting leaf state of the path.
//   final StateKey from;

//   /// The final state of the path.
//   ///
//   /// This may be either a leaf or non-leaf state.
//   final StateKey to;

//   /// The states that will be entered as the path is traversed.
//   final List<StateKey> entering;

//   /// The states that will be exited as the path is traversed.
//   final List<StateKey> exiting;

//   /// The path of nodes to traverse, starting at [from] and ending at [to].
//   late final List<StateKey> path = List.unmodifiable(exiting.followedBy(entering));

//   /// Constructs a [TransitionPath] instance.
//   TransitionPath(
//     this.from,
//     this.to,
//     Iterable<StateKey> exiting,
//     Iterable<StateKey> entering,
//   )   : exiting = List.unmodifiable(exiting),
//         entering = List.unmodifiable(entering);
// }

class Transition {
  /// The starting leaf state of the transition.
  final StateKey from;

  /// The final leaf state of the transition.
  final StateKey to;

  /// Complete list of states that were traversed (exited states followed by entered states) during
  /// the transition.
  ///
  /// The first state in the list is [from], and the last state in the list is [to].
  late final List<StateKey> path = List.unmodifiable(exitPath.followedBy(entryPath));

  /// The states that were exited during the transition.
  ///
  /// The order of the states in the list reflects the order the states were exited.
  final List<StateKey> exitPath;

  /// The states that were entered during the transition.
  ///
  /// The order of the states in the list reflects the order the states were entered.
  final List<StateKey> entryPath;

  Transition(
    this.from,
    this.to,
    Iterable<StateKey> exitPath,
    Iterable<StateKey> entryPath,
  )   : exitPath = List.unmodifiable(exitPath),
        entryPath = List.unmodifiable(entryPath);

  StateKey get lca => throw UnimplementedError();
}

//==================================================================================================
//
// Processing results
//

/// Base class for types describing how a message was processed by a state machine.
abstract class ProcessedMessage {
  /// The message that was processed.
  final Object message;

  /// The leaf state that first received the message.
  final StateKey receivingState;

  const ProcessedMessage._(this.message, this.receivingState);
}

/// A [ProcessedMessage] indicating that a state successfully handled a message.
class HandledMessage extends ProcessedMessage {
  /// The state that handled the message.
  ///
  /// This state might be different from [receivingState], if receiving state returned
  /// [MessageContext.unhandled] and delegated handling to an ancestor state.
  final StateKey handlingState;

  /// Returns a [Transition] describing the state transition that took place as a result of
  /// processing the message, or `null` if there was no transition.
  final Transition? transition;

  const HandledMessage(
    Object message,
    StateKey receivingState,
    this.handlingState, [
    this.transition,
  ]) : super._(message, receivingState);

  /// The
  // Iterable<StateKey> get exitedStates => transition?.exitPath ?? const [];
  // Iterable<StateKey> get enteredStates => transition?.entryPath ?? const [];
}

/// A [ProcessedMessage] indicating that none of the active states in the state machine recognized
/// the message.
class UnhandledMessage extends ProcessedMessage {
  /// The collection of states that were notified of, but did not handle, the message.
  final Iterable<StateKey> notifiedStates;
  const UnhandledMessage(Object message, StateKey receivingState, this.notifiedStates)
      : super._(message, receivingState);
}

/// A [ProcessedMessage] indicating an error was thrown while processing a message.
class FailedMessage extends ProcessedMessage {
  /// The error object that was thrown.
  final Object error;

  /// The stack trace at the point the error was thrownn
  final StackTrace stackTrace;

  const FailedMessage(Object message, StateKey receivingState, this.error, this.stackTrace)
      : super._(message, receivingState);
}

//==================================================================================================
//
// Codecs
//
class StateDataCodec<D> {
  final Object? Function(D?) _encode;
  final D? Function(Object?) _decode;
  StateDataCodec(this._encode, this._decode);

  factory StateDataCodec.json(
    Map<String, dynamic>? Function(D) serialize,
    D Function(Map<String, dynamic>) deserialize,
  ) {
    return StateDataCodec<D>(
      (stateData) => stateData != null ? serialize(stateData) : null,
      (serialized) => deserialize(serialized as Map<String, dynamic>),
    );
  }

  Object? serialize(D? stateData) => _encode(stateData);

  D? deserialize(Object? serialized) => _decode(serialized);
}
