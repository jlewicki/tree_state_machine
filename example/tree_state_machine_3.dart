import 'package:meta/meta.dart';
import 'package:tree_state_machine/src/lazy.dart';

// //
// // Example
// //
// class GameStartingData extends StateData {
//   String selectedScenario = null;
//   String selectedUBoat = null;
// }

// class GameStartingState extends TreeState1<GameStartingData> {
//   Future _onEnter(TransitionContext transitionContext) {
//     return Future.value(1);
//   }

//   Future<MessageResult> _onMessage(MessageContext1<GameStartingMessage> msgCtx) async {
//     return msgCtx.goTo(() => GameInProgressState());
//   }

//   @override
//   StateHandler createHandler() => createMessageHandler<GameStartingMessage>(onMessage: _onMessage, onEnter: _onEnter);
// }

// class GameStartingMessage {}

// class GameInProgressData extends StateData {
//   String uboat;
// }

// class GameInProgressState extends TreeState1<GameInProgressData> {
//   @override
//   StateHandler createHandler() {
//     return null;
//   }
// }
