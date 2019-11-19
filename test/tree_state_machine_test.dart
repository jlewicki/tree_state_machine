import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';

class SimpleState extends TreeState {}

void main() {
  group('TreeStateMachine', () {
    test("is not started when created", () {
      var sm = TreeStateMachine.forLeaves([BuildLeaf(SimpleState())]);
      expect(sm.isStarted, equals(false));
    });

    test("has no current state when created", () {
      var sm = TreeStateMachine.forLeaves([BuildLeaf(SimpleState())]);
      expect(sm.currentState, equals(null));
    });

    test("has transitions stream when created", () {
      var sm = TreeStateMachine.forLeaves([BuildLeaf(SimpleState())]);
      expect(sm.transitions, isNotNull);
    });

    test("throws if constructed with null root", () {
      expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
    });
  });
}
