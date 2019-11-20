import 'package:tree_state_machine/tree_state_machine.dart';

class GameRootState extends EmptyTreeState {}

class GameStartingState extends EmptyTreeState {}

class ChooseScenarioState extends EmptyTreeState {}

class ChooseSpaceshipState extends EmptyTreeState {}

var gameTree = BuildRoot(
  state: () => GameRootState(),
  children: [
    BuildInterior(
      state: () => GameStartingState(),
      children: [
        BuildLeaf(() => ChooseScenarioState()),
        BuildLeaf(() => ChooseSpaceshipState()),
      ],
    ),
  ],
);
