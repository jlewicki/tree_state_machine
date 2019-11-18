import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/tree_state_machine_2.dart';

class TransitionContext {}

class MessageContext {
  final Object message;
  MessageContext(this.message);
}

class MessageContext1<M> {
  final M message;
  MessageContext1(this.message);
}

abstract class MessageResult {}

class GoTo extends MessageResult {}

class Unhandled extends MessageResult {}

typedef Future TransitionHandler(TransitionContext context);
typedef Future MessageHandler(MessageContext context);
typedef Future MessageHandler1<M>(MessageContext1<M> context);

class StateHandler {
  final TransitionHandler onEnter;
  final MessageHandler onMessage;
  final TransitionHandler onExit;
  StateHandler(this.onEnter, this.onMessage, this.onExit);
}

abstract class TreeState {
  StateHandler createHandler();
}

abstract class StateData {}

StateHandler createMessageHandler<M>(
    {TransitionHandler onEnter,
    @required MessageHandler1<M> onMessage,
    TransitionHandler onExit,
    bool throwOnUnknownMessage = false}) {
  MessageHandler rawHandler = (MessageContext ctx) {
    if (ctx.message is M) {
      return onMessage(MessageContext1(ctx.message as M));
    } else if (throwOnUnknownMessage) {
      return Future.error(Exception('RuntiMessage type '));
    }
    return Future.value(Unhandled());
  };

  return StateHandler(onEnter, rawHandler, onExit);
}

abstract class TreeState1<D extends StateData> extends TreeState {}

//
// Example
//
class GameStartingData extends StateData {
  String selectedScenario = null;
  String selectedUBoat = null;
}

class GameStartingState extends TreeState1<GameStartingData> {
  Future _onEnter(TransitionContext transitionContext) {
    return Future.value(1);
  }

  Future _onMessage(MessageContext1<GameStartingMessage> transitionContext) {
    return Future.value(1);
  }

  @override
  StateHandler createHandler() => createMessageHandler<GameStartingMessage>(onMessage: _onMessage, onEnter: _onEnter);
}

class GameStartingMessage {}
