import 'package:test/test.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';

void main() {
  group('TreeBuildContext', () {
    var rootState = StateKey("root");
    var interiorState = StateKey("interior");
    var leafState1 = StateKey("leaf1");
    var leafState2 = StateKey("leaf2");

    var treeBuilder = DeclarativeStateTreeBuilder.withRoot(
      rootState,
      InitialChild(interiorState),
      emptyState,
    )
      ..state(
        interiorState,
        emptyState,
        parent: rootState,
        initialChild: InitialChild(leafState1),
      )
      ..state(leafState1, emptyState, parent: interiorState)
      ..state(leafState2, emptyState, parent: interiorState);

    group('transformer', () {
      var filter1 = TreeStateFilter(name: 'Filter1');
      var filter2 = TreeStateFilter(name: 'Filter2');

      test('should apply extensions when building nodes', () {
        var buildCtx = TreeBuildContext(extendNodes: (b) {
          b.metadata({"nodeKey": b.nodeBuildInfo.key});
          b.filter(filter2);
          b.filter(filter1);
        });

        var builder = StateTreeBuilder(treeBuilder);
        var rootNode = builder.build(buildCtx);
        for (var node in rootNode.selfAndDescendants()) {
          expect(node.metadata["nodeKey"], equals(node.key));
          expect(node.filters.length, 2);
          expect(node.filters, contains(filter1));
          expect(node.filters, contains(filter2));
        }
      });
    });
  });
}
