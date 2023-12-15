import 'package:tree_state_machine/src/machine/machine.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_build.dart';

Machine createMachine(StateTreeBuilder builder) {
  return TestableTreeStateMachine(builder).machine;
}
