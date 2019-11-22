import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';

import 'tree_builders_test.dart';

class SimpleState extends EmptyTreeState {}

class SimpleState2 extends EmptyTreeState {}

void main() {
  group('TreeStateMachine', () {
    final state1 = SimpleState();
    final state1Key = StateKey.forState<SimpleState>();
    final state2 = SimpleState2();
    final state2Key = StateKey.forState<SimpleState2>();
    final leaves = [BuildLeaf((key) => state1), BuildLeaf((key) => state2)];

    group('Creation', () {
      test('should not be started when created', () {
        final sm = TreeStateMachine.forLeaves(leaves, state1Key);
        expect(sm.isStarted, equals(false));
      });

      test('should have no current state when created', () {
        final sm = TreeStateMachine.forLeaves(leaves, state1Key);
        expect(sm.currentState, equals(null));
      });

      test('should have transitions stream when created', () {
        final sm = TreeStateMachine.forLeaves(leaves, state2Key);
        expect(sm.transitions, isNotNull);
      });

      test('should be constructed with null root', () {
        expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
      });
    });

    group('Start', () {
      test('should throw when already started', () async {
        final sm = TreeStateMachine.forLeaves(leaves, state2Key);
        await sm.start();
        expect(() async => sm.start(), throwsStateError);
      });
    });
  });
}
