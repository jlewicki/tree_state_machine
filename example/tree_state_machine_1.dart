typedef ChildState InitialTransition();

abstract class TreeState {
  TreeState() {}
}

abstract class ChildState extends TreeState {}

class RootState extends TreeState {
  final List<ChildState> childStates;
  final InitialTransition initialTransition;
  RootState(this.childStates, this.initialTransition) {}
}

class InteriorState extends ChildState {
  final List<ChildState> childStates;
  final InitialTransition initialTransition;
  InteriorState(this.childStates, this.initialTransition) {}
}

class LeafState extends ChildState {}

//
// Example
//
class ChooseScenario extends LeafState {}

class ChooseUboat extends LeafState {}

class GameSetup extends InteriorState {
  GameSetup._(List<ChildState> childStates, InitialTransition initialTransition)
      : super(childStates, initialTransition) {}

  factory GameSetup() {
    var chooseScenario = ChooseScenario();
    var chooseUboat = ChooseUboat();
    var initialTransition = () {
      return chooseScenario;
    };
    return GameSetup._([chooseScenario, chooseUboat], initialTransition);
  }
}

class GameTree extends RootState {
  GameTree._(List<ChildState> childStates, InitialTransition initialTransition)
      : super(childStates, initialTransition) {}

  factory GameTree() {
    var gameSetup = GameSetup();
    var initialTransition = () {
      return gameSetup;
    };
    return GameTree._([gameSetup], initialTransition);
  }
}
