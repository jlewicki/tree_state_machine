// import 'package:tree_state_machine/src/tree_state.dart';

// //
// // Game Starting
// //
// class GameStartingData extends StateData {
//   String selectedScenario = null;
//   String selectedUBoat = null;
// }

// class GameStartingState extends DataTreeState<GameStartingData> {
//   @override
//   StateHandler createHandler() => createMessageHandler(onMessage: _onMessage, onEnter: _onEnter);

//   Future _onEnter(TransitionContext transitionContext) {
//     return Future.value(1);
//   }

//   Future<MessageResult> _onMessage(MessageContext1<GameStartingMessage> msgCtx) async {
//     return msgCtx.goTo(() => GameInProgressState());
//   }
// }

// class GameStartingMessage {}

// //
// // Game In Progress
// //
// class GameInProgressData extends StateData {
//   String uboat;
// }

// class GameInProgressState extends DataTreeState<GameInProgressData> {
//   @override
//   StateHandler createHandler() => StateHandler.noOp;

//   // List<Lazy<StateHandler>> childStates = [
//   //   Lazy(() => new))
//   // ]
// }

// //
// // GameRoot
// //
// class GameState extends TreeState {
//   @override
//   StateHandler createHandler() {
//     return null;
//   }
// }
