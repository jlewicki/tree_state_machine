// import 'package:meta/meta.dart';
// import 'package:tree_state_machine/src/lazy.dart';

abstract class StateKey {
  StateKey._() {}
  static StateKey named(String name) => ValueKey<String>(name);
  static StateKey forClass<T>() => ValueKey<Type>(_TypeLiteral<T>().type);
}

class ValueKey<T> extends StateKey {
  final T value;
  ValueKey(this.value) : super._() {}

  @override
  bool operator ==(dynamic other) {
    if (other.runtimeType != runtimeType) return false;
    final ValueKey<T> typedOther = other;
    return value == typedOther.value;
  }

  @override
  int get hashCode {
    int hash = 7;
    hash = 31 * hash + runtimeType.hashCode;
    hash = 31 * hash + value.hashCode;
    return hash;
  }
}

class _TypeLiteral<T> {
  Type get type => T;
}

class TreeState {
  final StateKey key;
  TreeState(this.key) {
    if (key == null) throw ArgumentError.notNull("key");
  }
}

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
