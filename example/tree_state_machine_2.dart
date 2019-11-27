import 'package:meta/meta.dart';

class TransitionContext {}

class MessageContext {
  Object message;
}

abstract class StateHandler {
  @visibleForOverriding
  void onEnter(TransitionContext ctx) {}

  @visibleForOverriding
  void onMessage(MessageContext ctx);

  @visibleForOverriding
  void onExit(TransitionContext ctx) {}
}

abstract class StateData {}

abstract class StateMessage {}

class EmptyData extends StateData {
  static final EmptyData instance = new EmptyData();
}

abstract class TreeState1<D extends StateData> {
  D _stateData;
  D get data => _stateData;

  D createInitialData();

  @visibleForOverriding
  onEnter(D stateData) {
    _stateData = stateData;
  }

  onExit() {}

  onMessage(MessageContext ctx) {}
}

class MessageContext1<M> {
  final M message;
  MessageContext1(this.message) {}

  void goToWithData<T extends TreeState1<D>, D extends StateData>(D data) {}
}

abstract class TreeState2<D extends StateData, M extends StateMessage> extends TreeState1<D> {}

class EmptyTreeState extends TreeState1<EmptyData> {
  @override
  EmptyData createInitialData() => EmptyData.instance;
}

//
// Example
//

//
// Game Starting
//
class GameStartingData extends StateData {
  String selectedScenario = null;
  String selectedUBoat = null;
}

class GameStartingState extends TreeState1<GameStartingData> {
  @override
  GameStartingData createInitialData() {
    return GameStartingData();
  }
}

//
// GameStarting <- ChooseScenario
//
class ChooseScenarioData extends StateData {
  List<String> availableScenarios = [];
  String selectedScenario = null;
}

class ChooseScenarioState extends TreeState1<ChooseScenarioData> {
  @override
  ChooseScenarioData createInitialData() {
    return null;
  }

  void onMessage(MessageContext ctx) {
    //ctx.goToWithData<ChooseUBoatState, ChooseUBoatData>(ChooseUBoatData());
  }
}

class SelectScenarioMessage extends StateMessage {
  final String scenario;
  SelectScenarioMessage(this.scenario);
}

//
// GameStarting <- ChooseScenario
//
class ChooseUBoatData extends StateData {
  List<String> availableUBoats = [];
  String selectedUBoat = null;
}

class ChooseUBoatState extends TreeState1<ChooseUBoatData> {
  @override
  ChooseUBoatData createInitialData() {
    return null;
  }
}
