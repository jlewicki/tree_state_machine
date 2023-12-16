import 'package:tree_state_machine/src/machine/machine.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/build.dart';

Machine createMachine(StateTreeBuildProvider builder) {
  return TestableTreeStateMachine(builder).machine;
}
