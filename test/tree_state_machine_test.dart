import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';

class SimpleState extends EmptyTreeState {}

void main() {
  group('TreeStateMachine', () {
    group('Creation', () {
      var state = SimpleState();
      var stateKey = StateKey.forState<SimpleState>();
      test("should not be started when created", () {
        var sm = TreeStateMachine.forLeaves([BuildLeaf((key) => state)], stateKey);
        expect(sm.isStarted, equals(false));
      });

      test("should have no current state when created", () {
        var sm = TreeStateMachine.forLeaves([BuildLeaf((key) => state)], stateKey);
        expect(sm.currentState, equals(null));
      });

      test("should have transitions stream when created", () {
        var sm = TreeStateMachine.forLeaves([BuildLeaf((key) => state)], stateKey);
        expect(sm.transitions, isNotNull);
      });

      test("should be constructed with null root", () {
        expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
      });
    });

    group("Start", () {});
  });
}
