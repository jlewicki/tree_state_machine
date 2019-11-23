import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

import 'tree_1.dart';

void main() {
  group('Machine', () {
    group('enterInitialState', () {
      final buildCtx = BuildContext();
      final rootNode = buildTree(buildCtx);
      final machine = Machine(rootNode, buildCtx.nodes);

      test('should follow initial children when starting at root', () async {
        final MachineTransitionContext transCtx = await machine.enterInitialState(rootNode.key);

        expect(transCtx.from, equals(r_key));

        expect(transCtx.to, equals(r_a_a_2_key));
        expect(
          transCtx.path(),
          orderedEquals([r_key, r_a_key, r_a_a_key, r_a_a_2_key]),
        );
      });

      test('should descend to initial state when initial state is a leaf', () async {
        final leafNode = buildCtx.nodes[r_b_1_key];
        final MachineTransitionContext transCtx = await machine.enterInitialState(leafNode.key);

        expect(transCtx.from, equals(r_key));
        expect(transCtx.to, equals(leafNode.key));
        expect(
          transCtx.path().map((ref) => ref),
          orderedEquals([r_key, r_a_b_key, r_b_1_key]),
        );
      });

      test(
          'should descend to initial state, then follow initial children, when initial state an interior',
          () async {
        final interiorNode = buildCtx.nodes[r_a_a_key];
        final MachineTransitionContext transCtx = await machine.enterInitialState(interiorNode.key);

        expect(transCtx.from, equals(r_key));
        expect(transCtx.to, equals(r_a_a_2_key));
        expect(
          transCtx.path(),
          orderedEquals([r_key, r_a_key, r_a_a_key, r_a_a_2_key]),
        );
      });

      test('should throw if initialChild returns null', () {
        final buildTree =
            BuildRoot.keyed(key: r_key, state: (key) => r, initialChild: (_) => null, children: [
          BuildLeaf.keyed(r_a_1_key, (key) => r_a_1),
        ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });

      test('should throw if initialChild references a state that is not a child', () {
        final buildTree = BuildRoot.keyed(
            key: r_key,
            state: (key) => r,
            initialChild: (_) => r_a_a_1_key,
            children: [
              BuildLeaf.keyed(r_a_1_key, (key) => r_a_1),
            ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });
    });
  });
}
