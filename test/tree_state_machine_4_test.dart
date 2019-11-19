import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine_4.dart';

class SimpleState extends TreeState {}

void main() {
  group('TreeStateMachine', () {
    test("is not started when created", () {
      var sm = TreeStateMachine.forLeaves([leaf(SimpleState())]);
      expect(sm.isStarted, equals(false));
    });

    test("has no current state when created", () {
      var sm = TreeStateMachine.forRoot(SimpleState());
      expect(sm.currentState, equals(null));
    });

    test("has transitions stream when created", () {
      var sm = TreeStateMachine.forRoot(SimpleState());
      expect(sm.transitions, isNotNull);
    });

    test("throws if constructed with null root", () {
      expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
    });
  });
}
