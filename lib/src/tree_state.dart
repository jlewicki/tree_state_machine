import 'dart:async';
import 'package:meta/meta.dart';

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
  static StateKey forState<T extends TreeState>() => _ValueKey<Type>(_TypeLiteral<T>().type);
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

// Wacky: https://github.com/dart-lang/sdk/issues/33297
class _TypeLiteral<T> {
  Type get type => T;
}

//
// States
//

/// An individual state within a tree state machine.
///
/// A tree state is defined by its behavior in response to messages, represented by the [onMessage]
/// implementation.
abstract class TreeState {
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

  FutureOr<void> onExit(TransitionContext context) {}
}

/// A final state within a tree state machine.
///
/// A final state indicates that that state machine has completed processing. No further message
/// handline or state transitions can occur once a final state has been entered.
///
/// A tree state machine may contain as many final states as necessary, in order to reflect the
/// different completion conditions of the state tree.
abstract class FinalTreeState extends TreeState {
  @nonVirtual
  @override
  FutureOr<void> onExit(TransitionContext context) {
    throw StateError('Can not leave a final state.');
  }

  @nonVirtual
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    throw StateError('Can not send message to a final state');
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

/// A [TransitionHandler] that returns immediately.
final TransitionHandler emptyTransitionHandler = (_) {};

/// A [MessageHandler] that always returns [MessageContext.unhandled].
final MessageHandler emptyMessageHandler = (ctx) => ctx.unhandled();

class EmptyTreeState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => context.unhandled();
}

/// Provides information to a state about the message that is being processed.
class MessageContext {
  /// The message that is being processed by the state machine.
  final Object message;

  MessageContext(this.message) {
    ArgumentError.notNull('message');
  }

  /// Returns a [MessageResult] indicating that a transition to the specified state should occur.
  ///
  /// A [TransitionHandler] may optionally be specified, indicating a function that should be called
  /// during the transition between states.
  MessageResult goTo(StateKey targetStateKey, {TransitionHandler transitionAction}) =>
      GoToResult(targetStateKey, transitionAction);

  /// Returns a [MessageResult] indicating that an internal transition should occur.
  ///
  /// An internal transition means that the current state will not change, and no entry and exit
  /// handlers will be called.
  MessageResult stay() => InternalTransitionResult.value;

  /// Returns a [MessageResult] indicating that a self-transition should occur.
  ///
  /// A self-transition means that the state that calls this method is exited and re-entered,
  /// calling the handler functions for the state.
  ///
  /// If the calling state is a leaf state, only that state is re-entered. If the calling state is a
  /// interior states, all the states from the current (i.e. leaf) state and the calling interior
  /// state a re-enterd.
  MessageResult goToSelf({TransitionHandler transitionAction}) =>
      SelfTransitionResult(transitionAction);

  /// Returns a [MessageResult] indicating the message could not be handled by a state, and that
  /// ancestor states should be given an opportunity to handle the message.
  MessageResult unhandled() => UnhandledResult.value;
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
}

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

class DelegateFinalState extends FinalTreeState {
  TransitionHandler entryHandler;

  DelegateFinalState(this.entryHandler) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext context) => entryHandler(context);

  @override
  FutureOr<void> onExit(TransitionContext context) {}
}

// Food for thought
// typedef L<T> = List<T> Function<S>(S, {T Function(int, S) factory});
// https://github.com/dart-lang/sdk/blob/master/docs/language/informal/generic-function-type-alias.md

// abstract class StateData {}
// /**
//  * Represents a state within a tree (i.e. hierarchical) state machine that has associated state data of type [D].
//  */
// abstract class DataTreeState<D extends StateData> extends TreeState {}

// /**
//  * Represents a state within a tree (i.e. hierarchical) state machine that has associated state data of type [D].
//  */
// abstract class DataTreeState<D extends StateData> implements TreeState {
//   final StateKey key;
//   DataTreeState(this.key) {
//     if (key == null) throw ArgumentError.notNull("key");
//   }
// }

// /**
//  * Represents a state within a tree (i.e. hierarchical) state machine.
//  */
// abstract class TreeState {
//   /**
//    * Creates a state handler representing the message processing behavior of the state.
//    */
//   StateHandler createHandler();
// }

// abstract class StateData {}

// /**
//  * Represents a state within a tree (i.e. hierarchical) state machine that has associated state data of type [D].
//  */
// abstract class DataTreeState<D extends StateData> extends TreeState {}

// /**
//  * Signature of functions that can process a state machine message.
//  */
// typedef Future<MessageResult> MessageHandler(MessageContext context);

// /**
//  * Signature of functions that can process a state machine message of type M.
//  */
// typedef Future<MessageResult> MessageHandler1<M>(MessageContext1<M> context);

// /**
//  * Signature of functions that can observe a state transition.
//  */
// typedef Future TransitionHandler(TransitionContext context);

// /**
//  * Defines methods for creating various kinds of [MessageResult].
//  */
// mixin MessageResultBuilder {
//   /**
//    * Creates a [MessageResult] indicating that the state machine should transition a new state.
//    */
//   MessageResult goTo(TreeState create()) {
//     return _GoTo(create);
//   }

//   /**
//    * Creates a [MessageResult] indicating that the state machine should transition a new state, initialized with the
//    * specified state data.
//    */
//   MessageResult goToWithData<D extends StateData>(DataTreeState<D> create(), D initialData) {
//     return _GoToWith(create, initialData);
//   }

//   /**
//    * Creates a [MessageResult] indicating that the current state did not recognize the message being processed, and
//    * therefore did not handle the message.
//    *
//    * The state machine should therefore give each ancestor states an opportunity to process the message
//    */
//   MessageResult unhandled() {
//     return unhandledInstance;
//   }
// }

// class MessageContext with MessageResultBuilder {
//   final Object message;
//   MessageContext(this.message);
// }

// class MessageContext1<M> with MessageResultBuilder {
//   final M message;
//   MessageContext1(this.message);
// }

// class TransitionContext {}

// abstract class MessageResult {}

// class StateHandler {
//   final TransitionHandler onEnter;
//   final MessageHandler onMessage;
//   final TransitionHandler onExit;
//   static final StateHandler noOp = StateHandler(null, null, null);

//   StateHandler(this.onEnter, this.onMessage, this.onExit);
// }

// Type _typeOf<T>() => T;

// StateHandler createMessageHandler<M>(
//     {TransitionHandler onEnter,
//     @required MessageHandler1<M> onMessage,
//     TransitionHandler onExit,
//     bool throwOnUnknownMessage = false}) {
//   MessageHandler rawHandler = (MessageContext ctx) {
//     if (ctx.message is M) {
//       return onMessage(MessageContext1(ctx.message as M));
//     } else if (throwOnUnknownMessage) {
//       final msg = 'Expected message type ${_typeOf<M>()}, received ${ctx.message.runtimeType}';
//       return Future.error(Exception(msg));
//     }
//     return Future.value(ctx.unhandled());
//   };

//   return StateHandler(onEnter, rawHandler, onExit);
// }

// class _GoTo extends MessageResult {
//   final Lazy<TreeState> targetState;
//   _GoTo(TreeState create()) : targetState = Lazy(create);
// }

// class _GoToWith<D extends StateData> extends MessageResult {
//   final Lazy<DataTreeState<D>> targetState;
//   final D initialData;
//   _GoToWith(DataTreeState<D> create(), this.initialData) : targetState = Lazy(create);
// }

// class _Unhandled extends MessageResult {
//   _Unhandled._() {}
// }

// final unhandledInstance = _Unhandled._();
