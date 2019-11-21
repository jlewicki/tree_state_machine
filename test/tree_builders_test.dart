import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class SimpleState extends EmptyTreeState {}

void main() {
  var state = SimpleState();
  var stateKey = StateKey.named('state');
  var childState1 = SimpleState();
  var childState1Key = StateKey.named('childState1');
  var childState2 = SimpleState();
  var childState2Key = StateKey.named('childState2');
  var parentState = SimpleState();
  var parentKey = StateKey.named('parent');
  var parentNode = TreeNode(parentKey, () => parentState, null);

  group('BuildLeaf', () {
    test("builds a leaf node", () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf.keyed(stateKey, () => state);
      var leafNode = builder(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.key, equals(stateKey));
      expect(leafNode.isLeaf, isTrue);
      expect(leafNode.state(), same(state));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test("builds a leaf node with type-based state key", () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf(() => state);
      var leafNode = builder(buildCtx);
      expect(leafNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("adds node to context", () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf.keyed(stateKey, () => state);
      var leafNode = builder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(leafNode));
    });
  });

  group('BuildInterior', () {
    var buildInterior = BuildInterior.keyed(
      key: stateKey,
      state: () => state,
      children: [
        BuildLeaf.keyed(childState1Key, () => childState1),
        BuildLeaf.keyed(childState2Key, () => childState2),
      ],
      entryTransition: (_) => childState1Key,
    );

    test("builds an interior node", () {
      var buildCtx = BuildContext(parentNode);

      var interiorNode = buildInterior(buildCtx);

      expect(interiorNode, isNotNull);
      expect(interiorNode.key, equals(stateKey));
      expect(interiorNode.isInterior, isTrue);
      expect(interiorNode.state(), same(state));
      expect(interiorNode.parent, same(parentNode));
      expect(interiorNode.children, hasLength(2));
      interiorNode.children.forEach((c) {
        expect(c.parent, interiorNode);
      });
    });

    test("builds an interior node with type-based state key", () {
      var buildCtx = BuildContext(parentNode);

      var buildInterior = BuildInterior(
        state: () => state,
        children: [
          BuildLeaf.keyed(childState1Key, () => childState1),
          BuildLeaf.keyed(childState2Key, () => childState2),
        ],
        entryTransition: (_) => childState1Key,
      );

      var interiorNode = buildInterior(buildCtx);
      expect(interiorNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("adds node to context", () {
      var buildCtx = BuildContext(parentNode);

      var interiorNode = buildInterior(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(interiorNode));
      interiorNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('BuildRoot', () {
    var buildRoot = BuildRoot.keyed(
      key: stateKey,
      state: () => state,
      children: [
        BuildLeaf.keyed(childState1Key, () => childState1),
        BuildLeaf.keyed(childState2Key, () => childState2),
      ],
      entryTransition: (_) => childState1Key,
    );

    test("builds a root node", () {
      var buildCtx = BuildContext(null);

      var rootNode = buildRoot(buildCtx);

      expect(rootNode, isNotNull);
      expect(rootNode.key, equals(stateKey));
      expect(rootNode.isRoot, isTrue);
      expect(rootNode.state(), same(state));
      expect(rootNode.parent, isNull);
      expect(rootNode.children, hasLength(2));
      rootNode.children.forEach((c) {
        expect(c.parent, rootNode);
      });
    });

    test("builds an root node with type-based state key", () {
      var buildCtx = BuildContext(null);

      var buildRoot = BuildRoot(
        state: () => state,
        children: [
          BuildLeaf.keyed(childState1Key, () => childState1),
          BuildLeaf.keyed(childState2Key, () => childState2),
        ],
        entryTransition: (_) => childState1Key,
      );

      var rootNode = buildRoot(buildCtx);
      expect(rootNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("throws if built with a parent node", () {
      var buildCtx = BuildContext(parentNode);
      expect(() => buildRoot(buildCtx), throwsArgumentError);
    });

    test("adds node to context", () {
      var buildCtx = BuildContext(null);

      var rootNode = buildRoot(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(rootNode));
      rootNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group("BuildContext", () {
    test("throws if node with duplicate key is added", () {
      var buildCtx = BuildContext(parentNode);
      var key = StateKey.named("Foo");
      var builder = BuildLeaf.keyed(key, () => state);

      builder(buildCtx);

      expect(() => builder(buildCtx), throwsArgumentError);
    });
  });
}
