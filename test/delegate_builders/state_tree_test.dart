import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

void main() {
  group('StateTree', () {
    var rootState = StateKey('r');
    var r_1 = StateKey('r_1');
    var r_1_1 = StateKey('r_1_1');
    var r_1_2 = StateKey('r_1_2');
    var r_2 = StateKey('r_2');

    var tree = StateTree.root(
      rootState,
      InitialChild(r_1),
      childStates: [
        State.composite(
          r_1,
          InitialChild(r_1_1),
          childStates: [
            State(r_1_1),
            State(r_1_2),
          ],
        ),
        State(r_2),
      ],
    );

    group('factory', () {
      test('should create root state', () {
        var buildCtx = TreeBuildContext();
        StateTreeBuilder(tree).build(buildCtx);

        var nodes = buildCtx.nodes;
        expect(nodes[rootState], isNotNull);
        expect(nodes[rootState], isA<RootNodeInfo>());

        var rootNode = nodes[rootState] as RootNodeInfo;
        expect(rootNode.key, equals(rootState));
        expect(rootNode.dataCodec, isNull);
        expect(rootNode.filters, isEmpty);
        expect(rootNode.metadata, isEmpty);
        expect(rootNode.children.length, equals(2));
        expect(rootNode.children[0].key, equals(r_1));
        expect(rootNode.children[1].key, equals(r_2));
      });
    });
  });
}
