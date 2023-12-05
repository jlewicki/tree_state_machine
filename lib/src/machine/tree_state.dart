import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

//==================================================================================================
//
// Keys
//

/// An identifier for a state within a tree state machine.
///
/// Keys must be unique within a tree of states.
sealed class StateKey {
  /// Construct a [StateKey] with the specifed name.
  ///
  /// The name must be unique within a state tree.
  const factory StateKey(String name) = _ValueKey<String>;
}

/// An identifier for a data state, carrying state data of type [D], within a
/// tree state machine.
///
/// [DataStateKey] is a phantom type, in that [D] is not used at runtime, but
/// is useful for documentation purposes, making the association between a data
/// state and its data type more obvious.
///
/// Keys must be unique within a tree of states. Note however that [DataStateKey]
/// incorporates the type [D] into it's identity, so different [DataStateKey]s may
/// share the same name as long as [D] differs.
class DataStateKey<D> extends _ValueKey<(Type, String)> implements StateKey {
  const DataStateKey(String name) : super((D, name));

  @override
  String toString() {
    var (type, name) = _value;
    return "$name<$type>";
  }
}

class _ValueKey<T> implements StateKey {
  final T _value;
  const _ValueKey(this._value);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is _ValueKey<T> && runtimeType == other.runtimeType && _value == other._value);

  @override
  int get hashCode {
    var hash = 7;
    hash = 31 * hash + runtimeType.hashCode;
    hash = 31 * hash + _value.hashCode;
    return hash;
  }

  @override
  String toString() => _value.toString();
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
abstract class TreeState {
  /// Processes a message that has been sent to this state.
  ///
  /// The [MessageContext] argument describes the message that was sent. Subclasses can inspect this
  /// message and trigger state transitions by calling various methods on this context, such as
  /// [MessageContext.goTo].
  ///
  /// If the state does not recognize the message, it can call [MessageContext.unhandled]. The state
  /// machine will then call [onMessage] on the parent state of this state, giving it an opportunity
  /// to handle the message.
  FutureOr<MessageResult> onMessage(MessageContext msgCtx);

  /// Called when this state is being entered during a state transition.
  ///
  /// Note that this method should be idempotent. It is possible, if unlikely, that when recovering
  /// from an error condition this method might be called more than once without a corresponding
  /// call to [onExit].
  FutureOr<void> onEnter(TransitionContext transCtx);

  /// Called when this state is being exited during a state transition.
  ///
  /// Subclasses can overide to dispose of resources or execute cleanup logic.
  ///
  /// Note that this method should be idempotent. It is possible, if unlikely, that when recovering
  /// from an error condition this method might be called more than once without a corresponding
  /// call to [onEnter].
  FutureOr<void> onExit(TransitionContext transCtx);

  /// Optional function to call when the state machine is being disposed.
  void dispose();
}

class DelegatingTreeState implements TreeState {
  final MessageHandler _onMessage;
  final TransitionHandler _onEnter;
  final TransitionHandler _onExit;
  final Dispose _onDispose;

  DelegatingTreeState(this._onMessage, TransitionHandler? onEnter, TransitionHandler? onExit,
      [Dispose? onDispose])
      : _onEnter = onEnter ?? emptyTransitionAction,
        _onExit = onExit ?? emptyTransitionAction,
        _onDispose = onDispose ?? emptyDispose;

  @override
  FutureOr<void> onEnter(TransitionContext transCtx) => _onEnter(transCtx);

  @override
  FutureOr<MessageResult> onMessage(MessageContext msgCtx) => _onMessage(msgCtx);

  @override
  FutureOr<void> onExit(TransitionContext transCtx) => _onExit(transCtx);

  @override
  void dispose() => _onDispose();
}

/// A tree state with an associated data value of type [D].
///
/// The [data] property provides access to a [DataValue] that encapsulates to the current state
/// data, as well as providing change notifications in the form of a [Stream]. This [DataValue]
/// is recreated each time she state is entered.
abstract class DataTreeState<D> extends TreeState {
  final _refDataValue = Ref<ClosableDataValue<D>?>(null);
  final D Function(TransitionContext) _initialData;

  DataTreeState(this._initialData);

  /// The data value associated with this state. Returns `null` when the state is not active.
  DataValue<D>? get data => _refDataValue.value;

  @override
  FutureOr<void> onEnter(TransitionContext transCtx) {
    // Typically _refDataValue.value will be null, since it is only initialized) when the state is
    // entered, and cleared when the state is exited. However, even if this is the first time the
    // state has been entered, it potentially might not be null, if the state machine was started
    // with startWith, and one or more initial data values were provided.
    if (_refDataValue.value == null) {
      initializeData(transCtx);
    }
  }

  @override
  FutureOr<void> onExit(TransitionContext transCtx) {
    assert(_refDataValue.value != null);
    _refDataValue.value?.close();
    _refDataValue.value = null;
  }

  @override
  void dispose() => _refDataValue.value?.close();

  void initializeData(TransitionContext transCtx, [D? initialData]) {
    assert(_refDataValue.value == null);
    var initialData_ = initialData ?? _initialData(transCtx);
    _refDataValue.value?.close();
    _refDataValue.value = isTypeOfExact<void, D>()
        ? VoidDataValue() as ClosableDataValue<D>
        : ClosableDataValue(initialData_);
  }
}

class DelegatingDataTreeState<D> extends DataTreeState<D> {
  final MessageHandler _onMessage;
  final TransitionHandler _onEnter;
  final TransitionHandler _onExit;
  final Dispose _onDispose;

  DelegatingDataTreeState(
    super.initialData,
    this._onMessage,
    this._onEnter,
    this._onExit,
    this._onDispose,
  );

  @override
  FutureOr<MessageResult> onMessage(MessageContext msgCtx) => _onMessage(msgCtx);

  @override
  FutureOr<void> onEnter(TransitionContext transCtx) {
    return super.onEnter(transCtx).bind((_) => _onEnter(transCtx));
  }

  @override
  FutureOr<void> onExit(TransitionContext transCtx) {
    return _onExit(transCtx).bind((_) => super.onExit(transCtx));
  }

  @override
  void dispose() {
    _onDispose();
    super.dispose();
  }
}

/// State data for a nested state machine state.
class NestedMachineData {
  CurrentState? _nestedCurrentState;

  /// The [CurrentState] of the nested state machine.
  CurrentState get nestedCurrentState {
    assert(_nestedCurrentState != null);
    return _nestedCurrentState!;
  }
}

/// Describes the initial state machine of a [StateTreeBuilder.machineState].
abstract class NestedMachine {
  /// Returns `true` if messages should be forwarded from a state machine to the nested state machine.
  bool get forwardMessages;

  ///  Returns `true` if the nested state machine should be disposed when the
  /// [StateTreeBuilder.machineState] is exited.
  bool get disposeMachineOnExit;

  /// Creates a nested [TreeStateMachine].
  FutureOr<TreeStateMachine> call(TransitionContext transCtx);
}

/// The message that is sent to a state machine when a nested state machine has reached a final
/// state.
class NestedTreeStateMachineDoneMessage {}

/// A state that encapsulates a nested state machine
///
/// When this state is entered, a nested state machine is created and started. When the nested
/// machine completes, this state will transition to a successor state, as determined the [onDone]
/// callback.
class NestedMachineState extends DataTreeState<NestedMachineData> {
  final NestedMachine nestedMachine;
  final MessageHandler Function(CurrentState nestedState) onDone;
  final bool Function(Transition transition)? isDone;
  final MessageHandler? _onDisposed;
  final whenDoneMessage = NestedTreeStateMachineDoneMessage();
  final whenDisposedMessage = Object();
  final Logger _log;
  CurrentState? nestedCurrentState;

  NestedMachineState(this.nestedMachine, this.onDone, this._log, this.isDone, this._onDisposed)
      : super(InitialData(() => NestedMachineData()).call);

  @override
  FutureOr<void> onEnter(TransitionContext transCtx) {
    return super.onEnter(transCtx).bind((_) async {
      var machine = await nestedMachine(transCtx);

      // Future that tells us when the nested machine is done.
      var done = machine.transitions.where((t) {
        if (t.isToFinalState) return true;
        return isDone != null ? isDone!(t) : false;
      }).map((_) => whenDoneMessage);

      // Future that tells us when the nested machine is disposed.
      var disposed = machine.lifecycle
          .firstWhere((s) => s == LifecycleState.disposed)
          .then((_) => whenDisposedMessage)
          .asStream();

      nestedCurrentState = await machine.start();
      data!.update((current) => current.._nestedCurrentState = nestedCurrentState);

      // Post a future that will notify the message handler when the nested machine is done.
      var group = StreamGroup<Object>();
      group.add(done);
      group.add(disposed);
      Future<Object> msgFuture = group.stream.first;
      transCtx.post(msgFuture);
    });
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext msgCtx) async {
    // The nested state machine is done, so transition to the next state
    if (msgCtx.message == whenDoneMessage) {
      _log.fine(
          "Nested state machine reached final state '${nestedCurrentState!.key}' and is done.");
      var handler = onDone(nestedCurrentState!);
      return handler(msgCtx);
    }

    // The nested state machine was disposed, so transition to the next state
    if (msgCtx.message == whenDisposedMessage) {
      _log.fine("Nested state machine was disposed");
      if (_onDisposed != null) {
        return _onDisposed(msgCtx);
      } else {
        throw StateError('');
      }
    }

    // Dispatch messages sent to parent state machine to the child state machine.
    if (nestedMachine.forwardMessages) {
      _log.finer('Forwarding message ${msgCtx.message} to nested state machine.');
      await nestedCurrentState!.post(msgCtx.message);
    }

    // The nested machine is still running, so stay in this state
    return msgCtx.stay();
  }

  @override
  FutureOr<void> onExit(TransitionContext transCtx) {
    if (nestedMachine.disposeMachineOnExit) {
      nestedCurrentState?.stateMachine.dispose();
    }
    return super.onExit(transCtx);
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

  /// Identifies the currently active leaf state.
  StateKey get leafState;

  /// Identifies the active state that is currently processing a message.
  ///
  /// This may be an ancestor of [leafState], if the leaf state did not handle the message.
  StateKey get handlingState;

  /// The states that are currently active, starting at the active leaf state and ending at the
  /// root.
  Iterable<StateKey> get activeStates;

  /// A map for storing application data.
  ///
  /// This map may be useful for storing application-specific values that might need to shared across
  /// various message handlers as a message is processed. This map will never be read or modified by
  /// the state machine.
  Map<String, Object> get appData;

  /// Returns a [MessageResult] indicating that a transition to the specified state should occur.
  ///
  /// A [transitionAction] may optionally be specified. This function that will be called during the
  /// transition between states, after all states are exited, but before entering any new states.
  ///
  /// A [payload] may be optionally specified. This payload will be made available by
  /// [TransitionContext.payload] to the states that are exited and entered during the state
  /// transition, and can be used to provide additional application specific context describing
  /// the transition.
  ///
  /// A [reenterTarget] flag may be optionally specified. If `true`, and the target state is an
  /// active state, then the target state will be exited and entered, calling [TreeState.onExit] and
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

  /// Gets the [DataValue] matching the type [D] and [key] from the current state, or one of
  /// its ancestor states.
  DataValue<D>? data<D>([DataStateKey<D>? key]);

  /// Schedules a message to be dispatched to the state machine asynchronously.
  ///
  /// The time at which the message is sent is indicated by the [duration] argument. If not
  /// specified, it will be sent as soon as possible (but still asynchronously).
  ///
  /// If [periodic] is true, then messages will be dispatched repeatedly, at intervals specified by
  /// [duration]. Note that a [Timer] is used in the underlying implemention. Refer to
  /// [Timer.periodic] for further details regarding scheduling. Note that the [message] function
  /// will be evaluated a each interval.
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

  @override
  String toString() {
    return "GoToResult(targetState: '$targetStateKey'${payload != null ? ', payload: ${payload!}' : ''}${reenterTarget ? ', reenterTarget: true' : ''})";
  }
}

/// A [MessageResult] indicating that a message was successfully handled, and an internal transition
/// should occur. That is, the current state should remain the same.
class InternalTransitionResult extends MessageResult {
  InternalTransitionResult._() : super._();
  static final InternalTransitionResult value = InternalTransitionResult._();

  @override
  String toString() {
    return "InternalTransitionResult";
  }
}

/// A [MessageResult] indicating that a message was sucessfully handled, and an self transition
/// should occur. That is, the current state should remain the same, but the exit and entry handlers
/// for the state should be called.
class SelfTransitionResult extends MessageResult {
  final TransitionAction? transitionAction;
  SelfTransitionResult([this.transitionAction = emptyTransitionAction]) : super._();

  @override
  String toString() {
    return "SelfTransitionResult";
  }
}

/// A [MessageResult] indicating that a state machine is being stopped by application code.
class StopResult extends MessageResult {
  StopResult._() : super._();
  static final StopResult value = StopResult._();
}

/// A [MessageResult] indicating that a state did not recognize or handle a message.
class UnhandledResult extends MessageResult {
  UnhandledResult._() : super._();
  factory UnhandledResult() {
    return value;
  }
  static final UnhandledResult value = UnhandledResult._();

  @override
  String toString() {
    return "UnhandledResult";
  }
}

//==================================================================================================
//
// Transitions
//

/// Describes a transition between states that is occuring in a tree state machine.
abstract class TransitionContext {
  /// The path of states describing the transition path that was requested.
  ///
  /// Note that if a transition to a non-leaf state was requested, (that is, [Transition.to] of the
  /// requested transition refers to a non-leaf state), then when the transition completes, the
  /// current state will not be [Transition.to], but instead be a descendant state. This descendant
  /// is determined by following the initial child path starting at [Transition.to].
  Transition get requestedTransition;

  /// The states that have been entered during this transition.
  ///
  /// Because this transition may not yet be complete, there may be additional states that will be
  /// entered.
  Iterable<StateKey> get entered;

  /// The states that have been exited during this transition.
  ///
  /// Because this transition may not yet be complete, there may be additional states that will be
  /// entered.
  Iterable<StateKey> get exited;

  /// Identifies the active state that is currently handling the transition.
  StateKey get handlingState;

  /// The least common ancestor (LCA) state of the transition.
  ///
  /// The LCA state is the parent state of the last state exited and the first state entered during
  /// a transition, and consequently does not undergo a transition (that is, it is neither exited or
  /// entered).
  StateKey get lca;

  /// The optional payload for this transition.
  ///
  /// When a state transition is initiated with [MessageContext.goTo], the caller may provide an
  /// optional payload value that provides further context for the transition to the target state.
  /// This property makes this payload accessible during the transition.
  Object? get payload;

  DataValue<D>? data<D>([DataStateKey<D>? key]);

  /// Posts a message that should be sent to the end state of this transition, after the transition
  /// has completed.
  ///
  /// If [message] is a future, the value produced by the future will be posted when the future
  /// completes.
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
  /// [Timer.periodic] for further details regarding scheduling.
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

/// Describes a transition between states.
///
/// Depending on usage, this may describe a transition that will take place (as with
/// [TransitionContext.requestedTransition]), or a transition that has compeleted (as with
/// [HandledMessage.transition]).
class Transition {
  /// The starting leaf state of the transition.
  final StateKey from;

  /// The destination state of the transition.
  final StateKey to;

  /// The least common ancestor (LCA) state of the transition.
  ///
  /// The LCA state is the parent state of the last state exited and the first state entered during
  /// a transition, and consequently does not undergo a transition (that is, it is neither exited or
  /// entered).
  final StateKey lca;

  /// Complete list of states participating in the transition, comprised of the exiting states
  /// followed by the entering states.
  ///
  /// The first state in the list is [from], and the last state in the list is [to].
  late final List<StateKey> path = List.unmodifiable(exitPath.followedBy(entryPath));

  /// The exiting states for this transition.
  ///
  /// The order of the states in the list reflects the order of exit for the states.
  final List<StateKey> exitPath;

  /// The entering states for this transition.
  ///
  /// The order of the states in the list reflects the order of entry for the states.
  final List<StateKey> entryPath;

  ///
  final bool isToFinalState;

  Transition(
      this.from, this.to, this.lca, Iterable<StateKey> exitPath, Iterable<StateKey> entryPath,
      [bool? isToFinalState = false])
      : exitPath = List.unmodifiable(exitPath),
        entryPath = List.unmodifiable(entryPath),
        isToFinalState = isToFinalState ?? false;
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
    super.message,
    super.receivingState,
    this.handlingState, [
    this.transition,
  ]) : super._();
}

/// A [ProcessedMessage] indicating that none of the active states in the state machine recognized
/// the message.
class UnhandledMessage extends ProcessedMessage {
  /// The collection of states that were notified of, but did not handle, the message.
  final Iterable<StateKey> notifiedStates;
  const UnhandledMessage(super.message, super.receivingState, this.notifiedStates) : super._();
}

/// A [ProcessedMessage] indicating an error was thrown while processing a message.
class FailedMessage extends ProcessedMessage {
  /// The error object that was thrown.
  final Object error;

  /// The stack trace at the point the error was thrownn
  final StackTrace stackTrace;

  const FailedMessage(super.message, super.receivingState, this.error, this.stackTrace) : super._();
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

//==================================================================================================
//
// Filters
//

/// A function that is called to intercept the message handler of a state in a state tree.
///
/// If a state has an associated message filter, that filter will be called in lieu of the message
/// handler for the state. In addition to the message context, the filter is passed a [next]
/// function, that when called will call any remaining message filters for the state, followed by
/// calling the message handler for the state itself.
///
/// ```dart
/// var log = Logger();
/// MessageFilter loggingFilter = (msgCtx, next) async {
///   log.info('Calling the message handler for state ${msgCtx.handlingState}');
///   var result = await next();
///   log.info('Called the message handler for state ${msgCtx.handlingState}');
/// }
/// ```
typedef MessageFilter = Future<MessageResult> Function(
  MessageContext msgCtx,
  Future<MessageResult> Function() next,
);

/// A function that is called to intercept a transition handler of a state in a state tree.
///
/// If a state has an associated onEntry or onExit transition filter, that filter will be called in
/// lieu of the transition handler for the state. In addition to the transition context, the filter
/// is passed a [next] function, that when called will call any remaining transition filters for the
/// state, followed by calling the transition handler for the state itself.
///
///  ```dart
/// var log = Logger();
/// TransitionFilter loggingOnEntryFilter = (transCtx, next) async {
///   log.info('Calling the onEnter handler for state ${transCtx.handlingState}');
///   var result = await next();
///   log.info('Called the onEnter handler for state ${transCtx.handlingState}');
/// }
/// ```
typedef TransitionFilter = Future<void> Function(
  TransitionContext ctx,
  Future<void> Function() next,
);

class TreeStateFilter {
  TreeStateFilter({
    this.name,
    this.onMessage,
    this.onEnter,
    this.onExit,
  });
  final String? name;
  final MessageFilter? onMessage;
  final TransitionFilter? onEnter;
  final TransitionFilter? onExit;
}
