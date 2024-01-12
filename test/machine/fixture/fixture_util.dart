import 'package:test/test.dart';
import 'package:tree_state_machine/src/machine/machine.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

Machine createMachine(StateTreeBuildProvider builder, {int redirectLimit = 5}) {
  return TestableTreeStateMachine(builder, redirectLimit: redirectLimit)
      .machine;
}

final throwsRedirectError = throwsA(isA<RedirectError>());
