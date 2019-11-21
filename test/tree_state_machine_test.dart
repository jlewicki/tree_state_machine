import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';

class SimpleState extends EmptyTreeState {}

void main() {
  group('TreeStateMachine', () {
    var state = SimpleState();
    var stateKey = StateKey.forState<SimpleState>();
    test("is not started when created", () {
      var sm = TreeStateMachine.forLeaves([BuildLeaf(() => state)], stateKey);
      expect(sm.isStarted, equals(false));
    });

    test("has no current state when created", () {
      var sm = TreeStateMachine.forLeaves([BuildLeaf(() => state)], stateKey);
      expect(sm.currentState, equals(null));
    });

    test("has transitions stream when created", () {
      var sm = TreeStateMachine.forLeaves([BuildLeaf(() => state)], stateKey);
      expect(sm.transitions, isNotNull);
    });

    test("throws if constructed with null root", () {
      expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
    });
  });
}
