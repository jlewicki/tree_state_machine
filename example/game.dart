import 'package:tree_state_machine/tree_state_machine.dart';

class GameRootState extends EmptyTreeState {
  GameRootState() : super(StateKey.forClass<GameRootState>()) {}
}

class GameStartingState extends EmptyTreeState {
  GameStartingState() : super(StateKey.forClass<GameStartingState>()) {}
}

class ChooseScenarioState extends EmptyTreeState {
  ChooseScenarioState() : super(StateKey.forClass<ChooseScenarioState>()) {}
}

class ChooseSpaceshipState extends EmptyTreeState {
  ChooseSpaceshipState() : super(StateKey.forClass<ChooseSpaceshipState>()) {}
}

var gameTree = BuildRoot(
  state: GameRootState(),
  children: [
    BuildInterior(
      state: GameStartingState(),
      children: [
        BuildLeaf(ChooseScenarioState()),
        BuildLeaf(ChooseSpaceshipState()),
      ],
    ),
  ],
);
