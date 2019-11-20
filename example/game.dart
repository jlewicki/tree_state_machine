import 'package:tree_state_machine/tree_state_machine.dart';

class GameRootState extends EmptyTreeState {
  GameRootState() : super(StateKey.forState<GameRootState>()) {}
}

class GameStartingState extends EmptyTreeState {
  GameStartingState() : super(StateKey.forState<GameStartingState>()) {}
}

class ChooseScenarioState extends EmptyTreeState {
  ChooseScenarioState() : super(StateKey.forState<ChooseScenarioState>()) {}
}

class ChooseSpaceshipState extends EmptyTreeState {
  ChooseSpaceshipState() : super(StateKey.forState<ChooseSpaceshipState>()) {}
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
