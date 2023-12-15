import 'package:tree_state_machine/src/machine/machine.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

Machine createMachine(DeclarativeStateTreeBuilder builder) {
  return TestableTreeStateMachine(builder.call).machine;
}
