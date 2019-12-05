import 'dart:async';
import 'package:meta/meta.dart';
import 'utility.dart';

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Keys
//

/// A [StateKey] is an indentifier for a state within a tree state machine.
///
/// Keys must be unique within a tree of states.
abstract class StateKey {
  StateKey._();

  /// Construct a [StateKey] with the specifed name.
  static StateKey named(String name) => _ValueKey<String>(name);

  /// Construct a [StateKey] with a name based on the specified state type.
  ///
  /// This may be useful if each state in a tree is represented by its own [TreeState] subclass, and
  /// therefore a unique name for the state can be inferred from the type name.
  static StateKey forState<T extends TreeState>() => _ValueKey<Type>(TypeLiteral<T>().type);
}

@immutable
class _ValueKey<T> extends StateKey {
  final T value;
  _ValueKey(this.value) : super._() {
    ArgumentError.notNull('value');
  }

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
  String toString() => 'StateKey($value)';
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// States
//

/// An individual state within a tree state machine.
///
/// A tree state is defined by its behavior in response to messages, represented by the [onMessage]
/// implementation.
abstract class TreeState {
  /// Called when this state is being entered during a state transition.
  ///
  /// Subclasses can overide to initialize data associated with the state.
  ///
  /// Note that this method should be idempotent. It is possible, if unlikely, that when recovering
  /// from an error condition this method might be called more than once without a corresponding
  /// call to [onExit].
  FutureOr<void> onEnter(TransitionContext context) {}

  /// Processes a message that has been sent to this state.
  ///
  /// The [MessageContext] argument describes the message that was sent. Subclasses can inspect this
  /// message and trigger state transitions by calling various methods on this context, such as
  /// [MessageContext.goTo].
  ///
  /// If the state does not recognize the message, it can call [MessageContext.unhandled]. The state
  /// machine will then call [onMessage] on the parent state of this state, giving it an opportunity
  /// to handle the message.
  FutureOr<MessageResult> onMessage(MessageContext context);

  /// Called when this state is being exited during a state transition.
  ///
  /// Subclasses can overide to dispose of resources or execute cleanup logic.
  ///
  /// Note that this method should be idempotent. It is possible, if unlikely, that when recovering
  /// from an error condition this method might be called more than once without a corresponding
  /// call to [onEnter].
  FutureOr<void> onExit(TransitionContext context) {}
}

/// A final state within a tree state machine.
///
/// A final state indicates that that state machine has completed processing. No further message
/// handline or state transitions can occur once a final state has been entered.
///
/// A tree state machine may contain as many final states as necessary, in order to reflect the
/// different completion conditions of the state tree.
abstract class FinalTreeState implements TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {}

  /// Final states cannot be exited, so a [StateError] is thrown if called.
  @override
  @nonVirtual
  FutureOr<void> onExit(TransitionContext context) {
    throw StateError('Can not leave a final state.');
  }

  /// Final states cannot handle messages, so a [StateError] is thrown if called.
  @override
  @nonVirtual
  FutureOr<MessageResult> onMessage(MessageContext context) {
    throw StateError('Can not send message to a final state');
  }
}

/// Provides access to an externally managed data value.
abstract class DataValue<D> {
  /// The data value provided by this instance.
  D get data;
}

/// A tree state that supports serialization of its state data.
///
///
abstract class DataTreeState<D> extends TreeState {
  DataValue<D> _dataValue;

  /// The serializable data associated with this state.
  D get data {
    if (_dataValue == null) {
      throw StateError('Data value has not been initialized.');
    }
    return _dataValue.data;
  }

  /// Called to initialize the data value for this instance.
  ///
  /// This will be called by the state machine immediately after it creates this state instance.
  @mustCallSuper
  void initializeDataValue(DataValue<D> dataValue) {
    _dataValue = dataValue;
  }
}

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

/// Type of functions that are used to signal that resources can be released.
typedef Dispose = void Function();

/// A [TransitionHandler] that returns immediately.
final TransitionHandler emptyTransitionHandler = (_) {};

/// A [MessageHandler] that always returns [MessageContext.unhandled].
final MessageHandler emptyMessageHandler = (ctx) => ctx.unhandled();

/// A tree state that always returns [MessageContext.unhandled].
class EmptyTreeState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => context.unhandled();
}

class EmptyDataTreeState<D> extends DataTreeState<D> {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => context.unhandled();
}

////////////////////////////////////////////////////////////////////////////////////////////////////
//
// Contexts
//

/// Provides information to a state about the message that is being processed.
abstract class MessageContext {
  /// The message that is being processed by the state machine.
  Object get message;

  /// Returns a [MessageResult] indicating that a transition to the specified state should occur.
  ///
  /// A [TransitionHandler] may optionally be specified, indicating a function that should be called
  /// during the transition between states.
  MessageResult goTo(StateKey targetStateKey, {TransitionHandler transitionAction});

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
  /// If the calling state is a leaf state, only that state is re-entered. If the calling state is a
  /// interior states, all the states from the current (i.e. leaf) state and the calling interior
  /// state a re-enterd.
  MessageResult goToSelf({TransitionHandler transitionAction});

  /// Returns a [MessageResult] indicating the message could not be handled by a state, and that
  /// ancestor states should be given an opportunity to handle the message.
  MessageResult unhandled();

  /// Schedules a message to be dispatched to the state machine asynchronously.
  ///
  /// The time at which the message is sent is indicated by the [duration] argument. If not
  /// specified, it will be sent as soon as possible (but still asynchronously).
  ///
  /// If [periodic] is true, then messages will be dispatched repeatedly, at intervals specified by
  /// [duration]. Note that a [Timer] is used in the underlying implemention. Refer to
  /// [Timer.periodic(duration, callback)] for further details regarding scheduling.
  ///
  /// This scheduling is only valid for the state that calls this method. If a state transition
  /// occurs and this state is exited, the scheduling is automatically cancelled.
  ///
  /// The returned [Dispose] can be used to cancel the scheduled messaging (periodic or
  /// otherwise).
  Dispose schedule(
    Object message(), {
    Duration duration = const Duration(),
    bool periodic = false,
  });
}

/// Describes a transition between states that is occuring in a tree state machine.
abstract class TransitionContext {
  /// The source state of the transition.
  StateKey get from;

  /// The destination state of the transition. That is, the requested end state of the transition
  /// when it was initiated.
  ///
  /// Note that this state is not necessarily the final end state of the transition. If this property
  /// refers to a non-leaf state, then additional states will be traversed as the initial child
  /// path rooted at this state is followed, to arrive at the final leaf state for this transition.
  StateKey get to;

  /// The end state of the transition.
  ///
  /// This will refer to the final leaf state of the transition, including the result of following
  /// the initial child path rooted at [to], if [to] referes to a non-leaf state.
  StateKey get end;

  /// The path of states in the tree starting at [from] and ending at [to].
  Iterable<StateKey> get path;

  /// The path of states that has been currently been traversed (exited or entered) during this
  /// transition.
  Iterable<StateKey> traversed();

  /// The states that have currently been exited during this transition.
  ///
  /// The ordering in this collection reflects the order the states were exited.
  Iterable<StateKey> get exited;

  /// The states that have currently been entered during this transition.
  ///
  /// The ordering in this collection reflects the order the states were entered.
  Iterable<StateKey> get entered;

  /// Posts a message that should be sent to the end state of this transition, after the transition
  /// has completed.
  void post(Object message);
}

/// Describes a transition between states in a state machine.
@immutable
class Transition {
  /// The starting leaf state of the transition.
  final StateKey from;

  /// The final leaf state of the transition.
  final StateKey to;

  /// Complete list of states that were traversed (exited states followed by entered states) during
  /// the transition.
  ///
  /// The first state in the list is [from], and the last state in the list is [to].
  final List<StateKey> traversed;

  /// The states that were exited during the transition.
  ///
  /// The order of the states in the list reflects the order the states were exited.
  final List<StateKey> exited;

  /// The states that were entered during the transition.
  ///
  /// The order of the states in the list reflects the order the states were entered.
  final List<StateKey> entered;

  /// Constructs a [Transition] instance.
  Transition(
    this.from,
    this.to,
    Iterable<StateKey> traversed,
    Iterable<StateKey> exited,
    Iterable<StateKey> entered,
  )   : assert(traversed.first == from, 'from must be the same as the first traversed state'),
        assert(traversed.last == to, 'from must be the same as the last traversed state'),
        assert(exited.isEmpty || exited.first == from, 'from must be same as first exited state'),
        assert(entered.last == to, 'to must be same as last entered state'),
        this.traversed = (traversed ?? const []).toList(growable: false),
        this.exited = (exited ?? const []).toList(growable: false),
        this.entered = (entered ?? const []).toList(growable: false) {
    ArgumentError.checkNotNull(from, 'from');
    ArgumentError.checkNotNull(to, 'to');
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
///
/// Message Results
///

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
  final StateKey toStateKey;
  final FutureOr<void> Function(TransitionContext) transitionAction;
  GoToResult(this.toStateKey, [this.transitionAction]) : super._();
}

/// A [MessageResult] indicating that a message was sucessfully handled, and an internal transition
/// should occur. That is, current state should remain the same.
class InternalTransitionResult extends MessageResult {
  InternalTransitionResult._() : super._();
  static final InternalTransitionResult value = InternalTransitionResult._();
}

/// A [MessageResult] indicating that a message was sucessfully handled, and an self transition
/// should occur. That is, current state should remain the same, but the exit and entry handlers for
/// the state should be called.
class SelfTransitionResult extends MessageResult {
  final FutureOr<void> Function(TransitionContext) transitionAction;
  SelfTransitionResult([this.transitionAction]) : super._();
}

/// A [MessageResult] indicating that a state did not recognize or handle a message,
class UnhandledResult extends MessageResult {
  UnhandledResult._() : super._();
  static final UnhandledResult value = UnhandledResult._();
}

////////////////////////////////////////////////////////////////////////////////////////////////////
///
/// Processing results
///

/// Base class for types describing how a message was processed by a state machine.
@immutable
abstract class MessageProcessed {
  /// The message that was processed.
  final Object message;

  /// The leaf state that first received the message.
  final StateKey receivingState;

  const MessageProcessed._(this.message, this.receivingState);
}

/// A [MessageProcessed] indicating that a state successfully handled a message.
///
/// A state transition might have taken place part of handling the message. If this is true
@immutable
class HandledMessage extends MessageProcessed {
  /// The state that handled the message.
  ///
  /// This state might be different from [receivingState], if receiving state returned
  /// [MessageContext.unhandled] and delegated handling to an ancestor state.
  final StateKey handlingState;

  /// Returns a [Transition] describing the state transition that took place as a result of
  /// processing the message, or `null` if there was no transition.
  final Transition transition;

  const HandledMessage(
    Object message,
    StateKey receivingState,
    this.handlingState, [
    this.transition,
  ]) : super._(message, receivingState);

  // Get rid of these?
  Iterable<StateKey> get exitedStates => transition?.exited ?? const [];
  Iterable<StateKey> get enteredStates => transition?.entered ?? const [];
}

@immutable
class UnhandledMessage extends MessageProcessed {
  final Iterable<StateKey> notifiedStates;
  const UnhandledMessage(Object message, StateKey receivingState, this.notifiedStates)
      : super._(message, receivingState);
}

@immutable
class ProcessingError extends MessageProcessed {
  final Object error;
  final StackTrace stackTrace;
  const ProcessingError(Object message, StateKey receivingState, this.error, this.stackTrace)
      : super._(message, receivingState);
}

////////////////////////////////////////////////////////////////////////////////////////////////////
///
/// Utility classes
///

/// A tree state that delegates its behavior to one or more external functions.
class DelegateState extends TreeState {
  TransitionHandler entryHandler;
  TransitionHandler exitHandler;
  MessageHandler messageHandler;

  DelegateState({this.entryHandler, this.exitHandler, this.messageHandler}) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
    exitHandler = exitHandler ?? emptyTransitionHandler;
    messageHandler = messageHandler ?? emptyMessageHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext context) => entryHandler(context);
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => messageHandler(context);
  @override
  FutureOr<void> onExit(TransitionContext context) => exitHandler(context);
}

/// A data tree state that delegates its behavior to one or more external functions.
class DelegateDataState<D> extends DataTreeState<D> {
  TransitionHandler entryHandler;
  TransitionHandler exitHandler;
  MessageHandler messageHandler;

  DelegateDataState({
    this.entryHandler,
    this.exitHandler,
    this.messageHandler,
  }) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
    exitHandler = exitHandler ?? emptyTransitionHandler;
    messageHandler = messageHandler ?? emptyMessageHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext context) => entryHandler(context);
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => messageHandler(context);
  @override
  FutureOr<void> onExit(TransitionContext context) => exitHandler(context);
}

/// A final tree state that delegates its behavior to one or more external functions.
class DelegateFinalState extends FinalTreeState {
  TransitionHandler entryHandler;

  DelegateFinalState(this.entryHandler) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext context) => entryHandler(context);
}
