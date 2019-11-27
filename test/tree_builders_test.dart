import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'package:tree_state_machine/src/tree_state.dart';

class SimpleState extends EmptyTreeState {}

class SimpleTerminalState extends TerminalTreeState {}

void main() {
  var state = SimpleState();
  var stateKey = StateKey.named('state');
  var childState1 = SimpleState();
  var childState1Key = StateKey.named('childState1');
  var childState2 = SimpleState();
  var childState2Key = StateKey.named('childState2');
  var parentState = SimpleState();
  var parentKey = StateKey.named('parent');
  var parentNode = TreeNode(parentKey, (key) => parentState, null);
  var terminalState = SimpleTerminalState();
  var terminalKey = StateKey.named('terminal');

  group('BuildLeaf', () {
    test('should build a leaf node', () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf.keyed(stateKey, (key) => state);
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

      var builder = BuildLeaf((key) => state);
      var leafNode = builder(buildCtx);
      expect(leafNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should add node to context', () {
      var buildCtx = BuildContext(parentNode);

      var builder = BuildLeaf.keyed(stateKey, (key) => state);
      var leafNode = builder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(leafNode));
    });
  });

  group('BuildInterior', () {
    var buildInterior = BuildInterior.keyed(
      key: stateKey,
      state: (key) => state,
      children: [
        BuildLeaf.keyed(childState1Key, (key) => childState1),
        BuildLeaf.keyed(childState2Key, (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build an interior node', () {
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

    test('should build an interior node with type-based state key', () {
      var buildCtx = BuildContext(parentNode);

      var buildInterior = BuildInterior(
        state: (key) => state,
        children: [
          BuildLeaf.keyed(childState1Key, (key) => childState1),
          BuildLeaf.keyed(childState2Key, (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var interiorNode = buildInterior(buildCtx);
      expect(interiorNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("should add node to context", () {
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
      state: (key) => state,
      children: [
        BuildLeaf.keyed(childState1Key, (key) => childState1),
        BuildLeaf.keyed(childState2Key, (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build a root node', () {
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

    test('should build a root node with type-based state key', () {
      var buildCtx = BuildContext(null);

      var buildRoot = BuildRoot(
        state: (key) => state,
        children: [
          BuildLeaf.keyed(childState1Key, (key) => childState1),
          BuildLeaf.keyed(childState2Key, (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var rootNode = buildRoot(buildCtx);
      expect(rootNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should throw if built with a parent node', () {
      var buildCtx = BuildContext(parentNode);
      expect(() => buildRoot(buildCtx), throwsArgumentError);
    });

    test('should add node to context', () {
      var buildCtx = BuildContext(null);

      var rootNode = buildRoot(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(rootNode));
      rootNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('BuildTerminal', () {
    test('should build an terminal node', () {
      var buildCtx = BuildContext(parentNode);

      var buildTerminal = BuildTerminal.keyed(terminalKey, (key) => terminalState);
      var terminalNode = buildTerminal(buildCtx);

      expect(terminalNode, isNotNull);
      expect(terminalNode.key, equals(terminalKey));
      expect(terminalNode.isTerminal, isTrue);
      expect(terminalNode.state(), same(terminalState));
      expect(terminalNode.parent, same(parentNode));
      expect(terminalNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = BuildContext(parentNode);

      var buildTerminal = BuildTerminal((key) => terminalState);
      var terminalNode = buildTerminal(buildCtx);

      expect(terminalNode.key, equals(StateKey.forState<SimpleTerminalState>()));
    });

    test('should add node to context', () {
      var buildCtx = BuildContext(parentNode);

      var buildTerminal = BuildTerminal.keyed(terminalKey, (key) => terminalState);
      var terminalNode = buildTerminal(buildCtx);

      expect(buildCtx.nodes[terminalKey], equals(terminalNode));
    });
  });

  group('BuildContext', () {
    test('should throw if node with duplicate key is added', () {
      var buildCtx = BuildContext(parentNode);
      var key = StateKey.named("Foo");
      var builder = BuildLeaf.keyed(key, (key) => state);

      builder(buildCtx);

      expect(() => builder(buildCtx), throwsArgumentError);
    });
  });
}
