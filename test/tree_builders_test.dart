import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/tree_state_helpers.dart';
import 'package:tree_state_machine/tree_builders.dart';

import 'fixture/tree_data.dart';

class SimpleState extends EmptyTreeState {}

class SimpleDataState extends EmptyDataTreeState<SimpleDataA> {}

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
  var parentNode = TreeNode.root(parentKey, (key) => parentState, null);
  var finalState = SimpleFinalState();
  var finaKey = StateKey.named('final');

  final currentLeafData = DelegateObservableData();

  group('Leaf', () {
    test('should build a leaf node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var builder = Leaf(key: stateKey, createState: (key) => state);
      var leafNode = builder.build(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.key, equals(stateKey));
      expect(leafNode.isLeaf, isTrue);
      expect(leafNode.state(), same(state));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var builder = Leaf(createState: (key) => state);
      var leafNode = builder.build(buildCtx);
      expect(leafNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should add node to context', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var builder = Leaf(key: stateKey, createState: (key) => state);
      var leafNode = builder.build(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(leafNode));
    });
  });

  group('LeafWithData', () {
    test('should build a data leaf node', () {
      SimpleDataState theState;
      final buildCtx = TreeBuildContext(currentLeafData, parentNode);
      final builder = LeafWithData(
        key: stateKey,
        createState: (key) {
          return theState = SimpleDataState();
        },
        createProvider: SimpleDataA.dataProvider,
      );
      final leafNode = builder.build(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.key, equals(stateKey));
      expect(leafNode.isLeaf, isTrue);
      expect(leafNode.state(), same(theState));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test('should create new data provider', () {
      final builder = LeafWithData(
        key: stateKey,
        createState: (key) => SimpleDataState(),
        createProvider: SimpleDataA.dataProvider,
      );
      final leafNode1 = builder.build(TreeBuildContext(currentLeafData, parentNode));
      final leafNode2 = builder.build(TreeBuildContext(currentLeafData, parentNode));

      expect(identical(leafNode1.dataProvider, leafNode2.dataProvider), isFalse);
    });
  });

  group('Interior', () {
    var interiorBuilder = Interior(
      key: stateKey,
      createState: (key) => state,
      children: [
        Leaf(key: childState1Key, createState: (key) => childState1),
        Leaf(key: childState2Key, createState: (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build an interior node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var interiorNode = interiorBuilder.build(buildCtx);

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
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var nodeBuilder = Interior(
        createState: (key) => state,
        children: [
          Leaf(key: childState1Key, createState: (key) => childState1),
          Leaf(key: childState2Key, createState: (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var interiorNode = nodeBuilder.build(buildCtx);
      expect(interiorNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("should add node to context", () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var interiorNode = interiorBuilder.build(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(interiorNode));
      interiorNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('InteriorWithData', () {
    test('should build a data interior node', () {
      SimpleDataState theState;
      final buildCtx = TreeBuildContext(currentLeafData, parentNode);
      final builder = InteriorWithData(
          key: stateKey,
          createState: (key) {
            return theState = SimpleDataState();
          },
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [Leaf(createState: (_) => new SimpleState())]);
      final interiorNode = builder.build(buildCtx);

      expect(interiorNode, isNotNull);
      expect(interiorNode.key, equals(stateKey));
      expect(interiorNode.isInterior, isTrue);
      expect(interiorNode.state(), same(theState));
      expect(interiorNode.parent, same(parentNode));
      expect(interiorNode.children.length, equals(1));
    });

    test('should create new data provider', () {
      final builder = InteriorWithData(
          key: stateKey,
          createState: (key) => SimpleDataState(),
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [Leaf(createState: (_) => new SimpleState())]);
      final node1 = builder.build(TreeBuildContext(currentLeafData, parentNode));
      final node2 = builder.build(TreeBuildContext(currentLeafData, parentNode));

      expect(identical(node1.dataProvider, node2.dataProvider), isFalse);
    });
  });

  group('Root', () {
    var rootBuilder = Root(
      key: stateKey,
      createState: (key) => state,
      children: [
        Leaf(key: childState1Key, createState: (key) => childState1),
        Leaf(key: childState2Key, createState: (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build a root node', () {
      var buildCtx = TreeBuildContext(null);

      var rootNode = rootBuilder.build(buildCtx);

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
      var buildCtx = TreeBuildContext(null);

      var rootBuilder = Root(
        createState: (key) => state,
        children: [
          Leaf(key: childState1Key, createState: (key) => childState1),
          Leaf(key: childState2Key, createState: (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var rootNode = rootBuilder.build(buildCtx);
      expect(rootNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should throw if built with a parent node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);
      expect(() => rootBuilder.build(buildCtx), throwsStateError);
    });

    test('should add node to context', () {
      var buildCtx = TreeBuildContext(null);

      var rootNode = rootBuilder.build(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(rootNode));
      rootNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('RootWithData', () {
    test('should build a data leaf node', () {
      SimpleDataState theState;
      final buildCtx = TreeBuildContext(currentLeafData, null);
      final builder = RootWithData(
          key: stateKey,
          createState: (key) {
            return theState = SimpleDataState();
          },
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [Leaf(createState: (_) => new SimpleState())]);
      final rootNode = builder.build(buildCtx);

      expect(rootNode, isNotNull);
      expect(rootNode.key, equals(stateKey));
      expect(rootNode.isRoot, isTrue);
      expect(rootNode.state(), same(theState));
      expect(rootNode.parent, isNull);
      expect(rootNode.children.length, equals(1));
    });

    test('should create new data provider', () {
      final builder = RootWithData(
          key: stateKey,
          createState: (key) => SimpleDataState(),
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [Leaf(createState: (_) => new SimpleState())]);
      final node1 = builder.build(TreeBuildContext(currentLeafData, null));
      final node2 = builder.build(TreeBuildContext(currentLeafData, null));

      expect(identical(node1.dataProvider, node2.dataProvider), isFalse);
    });
  });

  group('Final', () {
    test('should build a final node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var finalBuilder = Final(key: finaKey, createState: (key) => finalState);
      var finalNode = finalBuilder.build(buildCtx);

      expect(finalNode, isNotNull);
      expect(finalNode.key, equals(finaKey));
      expect(finalNode.isFinal, isTrue);
      expect(finalNode.state(), same(finalState));
      expect(finalNode.parent, same(parentNode));
      expect(finalNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var finalBuilder = Final(createState: (key) => finalState);
      var finalNode = finalBuilder.build(buildCtx);

      expect(finalNode.key, equals(StateKey.forState<SimpleFinalState>()));
    });

    test('should add node to context', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var buildFinal = Final(key: finaKey, createState: (key) => finalState);
      var finalNode = buildFinal.build(buildCtx);

      expect(buildCtx.nodes[finaKey], equals(finalNode));
    });
  });

  group('BuildContext', () {
    test('should throw if node with duplicate key is added', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);
      var key = StateKey.named("Foo");
      var builder = Leaf(key: key, createState: (key) => state);

      builder.build(buildCtx);

      expect(() => builder.build(buildCtx), throwsArgumentError);
    });
  });
}
