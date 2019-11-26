import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';
import 'tree_1.dart' as deep_tree;
import 'flat_tree_1.dart' as flat_tree;

void main() {
  group('TreeStateMachine', () {
    group('forLeaves', () {
      test('should not be started when created', () {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        expect(sm.isStarted, equals(false));
      });

      test('should have no current state when created', () {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        expect(sm.currentState, equals(null));
      });

      test('should have transitions stream when created', () {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        expect(sm.transitions, isNotNull);
      });

      test('should be constructed with null root', () {
        expect(() => TreeStateMachine.forRoot(null), throwsArgumentError);
      });
    });

    group('start', () {
      test('should throw when already started', () async {
        final sm = TreeStateMachine.forLeaves(flat_tree.leaves, flat_tree.r_1_key);
        await sm.start();
        expect(() async => sm.start(), throwsStateError);
      });

      test('should set current state to initial state', () async {
        final sm = TreeStateMachine.forRoot(deep_tree.treeBuilder());

        final initialTransition = await sm.start();

        expect(sm.currentState, isNotNull);
        expect(sm.currentState.key, equals(deep_tree.r_a_a_2_key));
        expect(sm.currentState.key, equals(initialTransition.end));
      });

      test('should emit transition', () async {
        final sm = TreeStateMachine.forRoot(deep_tree.treeBuilder());
        final transitionsQ = StreamQueue(sm.transitions);

        final results = await Future.wait([transitionsQ.next, sm.start()]);

        final transition = results[0] as Transition;
        expect(transition.from, equals(deep_tree.r_key));
        expect(transition.to, equals(deep_tree.r_a_a_2_key));
        expect(
          transition.path,
          orderedEquals([
            deep_tree.r_key,
            deep_tree.r_a_key,
            deep_tree.r_a_a_key,
            deep_tree.r_a_a_2_key,
          ]),
        );
      });
    });
  });
}
