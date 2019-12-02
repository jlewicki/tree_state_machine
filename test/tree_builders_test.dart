import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class SimpleState extends EmptyTreeState {}

class SimpleFinalState extends FinalTreeState {}

void main() {
  var state = SimpleState();
  var stateKey = StateKey.named('state');
  var childState1 = SimpleState();
  var childState1Key = StateKey.named('childState1');
  var childState2 = SimpleState();
  var childState2Key = StateKey.named('childState2');
  var parentState = SimpleState();
  var parentKey = StateKey.named('parent');
  var parentNode = rootNode(parentKey, (key) => parentState, null);
  var finalState = SimpleFinalState();
  var finaKey = StateKey.named('final');

  group('BuildLeaf', () {
    test('should build a leaf node', () {
      var buildCtx = BuildContext(parentNode);

      var builder = buildLeaf(key: stateKey, createState: (key) => state);
      var leafNode = builder(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.key, equals(stateKey));
      expect(leafNode.isLeaf, isTrue);
      expect(leafNode.state(), same(state));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = BuildContext(parentNode);

      var builder = buildLeaf(createState: (key) => state);
      var leafNode = builder(buildCtx);
      expect(leafNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should add node to context', () {
      var buildCtx = BuildContext(parentNode);

      var builder = buildLeaf(key: stateKey, createState: (key) => state);
      var leafNode = builder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(leafNode));
    });
  });

  group('BuildInterior', () {
    var interiorBuilder = buildInterior(
      key: stateKey,
      state: (key) => state,
      children: [
        buildLeaf(key: childState1Key, createState: (key) => childState1),
        buildLeaf(key: childState2Key, createState: (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build an interior node', () {
      var buildCtx = BuildContext(parentNode);

      var interiorNode = interiorBuilder(buildCtx);

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

    test('should build an interior node with type-based state key', () {
      var buildCtx = BuildContext(parentNode);

      var interiorBuilder = buildInterior(
        state: (key) => state,
        children: [
          buildLeaf(key: childState1Key, createState: (key) => childState1),
          buildLeaf(key: childState2Key, createState: (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var interiorNode = interiorBuilder(buildCtx);
      expect(interiorNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("should add node to context", () {
      var buildCtx = BuildContext(parentNode);

      var interiorNode = interiorBuilder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(interiorNode));
      interiorNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('BuildRoot', () {
    var rootBuilder = buildRoot(
      key: stateKey,
      state: (key) => state,
      children: [
        buildLeaf(key: childState1Key, createState: (key) => childState1),
        buildLeaf(key: childState2Key, createState: (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build a root node', () {
      var buildCtx = BuildContext(null);

      var rootNode = rootBuilder(buildCtx);

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

    test('should build a root node with type-based state key', () {
      var buildCtx = BuildContext(null);

      var rootBuilder = buildRoot(
        state: (key) => state,
        children: [
          buildLeaf(key: childState1Key, createState: (key) => childState1),
          buildLeaf(key: childState2Key, createState: (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var rootNode = rootBuilder(buildCtx);
      expect(rootNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should throw if built with a parent node', () {
      var buildCtx = BuildContext(parentNode);
      expect(() => rootBuilder(buildCtx), throwsArgumentError);
    });

    test('should add node to context', () {
      var buildCtx = BuildContext(null);

      var rootNode = rootBuilder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(rootNode));
      rootNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('BuildFinal', () {
    test('should build a final node', () {
      var buildCtx = BuildContext(parentNode);

      var finalBuilder = buildFinal(key: finaKey, createState: (key) => finalState);
      var finalNode = finalBuilder(buildCtx);

      expect(finalNode, isNotNull);
      expect(finalNode.key, equals(finaKey));
      expect(finalNode.isFinal, isTrue);
      expect(finalNode.state(), same(finalState));
      expect(finalNode.parent, same(parentNode));
      expect(finalNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = BuildContext(parentNode);

      var finalBuilder = buildFinal(createState: (key) => finalState);
      var finalNode = finalBuilder(buildCtx);

      expect(finalNode.key, equals(StateKey.forState<SimpleFinalState>()));
    });

    test('should add node to context', () {
      var buildCtx = BuildContext(parentNode);

      var finalBuilder = buildFinal(key: finaKey, createState: (key) => finalState);
      var finalNode = finalBuilder(buildCtx);

      expect(buildCtx.nodes[finaKey], equals(finalNode));
    });
  });

  group('BuildContext', () {
    test('should throw if node with duplicate key is added', () {
      var buildCtx = BuildContext(parentNode);
      var key = StateKey.named("Foo");
      var builder = buildLeaf(key: key, createState: (key) => state);

      builder(buildCtx);

      expect(() => builder(buildCtx), throwsArgumentError);
    });
  });
}
