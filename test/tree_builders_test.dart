import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class SimpleState extends EmptyTreeState {
  SimpleState(String name) : super(StateKey.named(name)) {}
}

void main() {
  var state = SimpleState("state");
  var childState1 = SimpleState("childState1");
  var childState2 = SimpleState("childState2");
  var parentState = SimpleState("parentState");
  var parentNode = TreeNode(parentState, null);

  group('BuildLeaf', () {
    test("builds a leaf node", () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf(state);
      var leafNode = builder(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.state, same(state));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test("adds node to context", () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf(state);
      var leafNode = builder(buildCtx);

      expect(buildCtx.nodes[state.key], equals(leafNode));
    });
  });

  group('BuildInterior', () {
    test("builds an interior node", () {
      var buildCtx = BuildContext(parentNode);

      var builder =
          BuildInterior(state: state, children: [BuildLeaf(childState1), BuildLeaf(childState2)]);
      var interiorNode = builder(buildCtx);

      expect(interiorNode, isNotNull);
      expect(interiorNode.state, same(state));
      expect(interiorNode.parent, same(parentNode));
      expect(interiorNode.children, hasLength(2));
      interiorNode.children.forEach((c) {
        expect(c.parent, interiorNode);
      });
    });

    test("adds node to context", () {
      var buildCtx = BuildContext(parentNode);

      var builder =
          BuildInterior(state: state, children: [BuildLeaf(childState1), BuildLeaf(childState2)]);
      var interiorNode = builder(buildCtx);

      expect(buildCtx.nodes[state.key], equals(interiorNode));
      interiorNode.children.forEach((c) {
        expect(buildCtx.nodes[c.state.key], equals(c));
      });
    });
  });

  group('BuildRoot', () {
    test("builds a root node", () {
      var buildCtx = BuildContext(null);

      var builder =
          BuildRoot(state: state, children: [BuildLeaf(childState1), BuildLeaf(childState2)]);
      var rootNode = builder(buildCtx);

      expect(rootNode, isNotNull);
      expect(rootNode.state, same(state));
      expect(rootNode.parent, isNull);
      expect(rootNode.children, hasLength(2));
      rootNode.children.forEach((c) {
        expect(c.parent, rootNode);
      });
    });

    test("throws if built with a parent node", () {
      var buildCtx = BuildContext(parentNode);

      var builder =
          BuildRoot(state: state, children: [BuildLeaf(childState1), BuildLeaf(childState2)]);
      expect(() => builder(buildCtx), throwsArgumentError);
    });

    test("adds node to context", () {
      var buildCtx = BuildContext(null);

      var builder =
          BuildRoot(state: state, children: [BuildLeaf(childState1), BuildLeaf(childState2)]);
      var rootNode = builder(buildCtx);

      expect(buildCtx.nodes[state.key], equals(rootNode));
      rootNode.children.forEach((c) {
        expect(buildCtx.nodes[c.state.key], equals(c));
      });
    });
  });
}
