import 'package:tree_state_machine/tree_state_machine.dart';

class GameRootState extends EmptyTreeState {}

class GameStartingState extends EmptyTreeState {}

class ChooseScenarioState extends EmptyTreeState {}

class ChooseSpaceshipState extends EmptyTreeState {}

var gameTree = BuildRoot(
  state: (key) => GameRootState(),
  initialChild: (_) => StateKey.forState<GameStartingState>(),
  children: [
    BuildInterior(
      state: (key) => GameStartingState(),
      initialChild: (_) => StateKey.forState<ChooseScenarioState>(),
      children: [
        BuildLeaf((key) => ChooseScenarioState()),
        BuildLeaf((key) => ChooseSpaceshipState()),
      ],
    ),
  ],
);
