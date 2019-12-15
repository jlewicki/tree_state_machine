import 'package:test/test.dart';
import 'package:tree_state_machine/src/data_provider.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'package:tree_state_machine/src/tree_state.dart';
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
  var parentNode = RootNode(parentKey, (key) => parentState, null);
  var finalState = SimpleFinalState();
  var finaKey = StateKey.named('final');

  final currentLeafData = DelegateObservableData();

  group('buildLeaf', () {
    test('should build a leaf node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var builder = leafBuilder(key: stateKey, createState: (key) => state);
      var leafNode = builder(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.key, equals(stateKey));
      expect(leafNode.isLeaf, isTrue);
      expect(leafNode.state(), same(state));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var builder = leafBuilder(createState: (key) => state);
      var leafNode = builder(buildCtx);
      expect(leafNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should add node to context', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var builder = leafBuilder(key: stateKey, createState: (key) => state);
      var leafNode = builder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(leafNode));
    });
  });

  group('buildDataLeaf', () {
    test('should build a data leaf node', () {
      SimpleDataState theState;
      final buildCtx = TreeBuildContext(currentLeafData, parentNode);
      final builder = dataLeafBuilder(
        key: stateKey,
        createState: (key) {
          return theState = SimpleDataState();
        },
        createProvider: SimpleDataA.dataProvider,
      );
      final leafNode = builder(buildCtx);

      expect(leafNode, isNotNull);
      expect(leafNode.key, equals(stateKey));
      expect(leafNode.isLeaf, isTrue);
      expect(leafNode.state(), same(theState));
      expect(leafNode.parent, same(parentNode));
      expect(leafNode.children, isEmpty);
    });

    test('should create new data provider', () {
      final builder = dataLeafBuilder(
        key: stateKey,
        createState: (key) => SimpleDataState(),
        createProvider: SimpleDataA.dataProvider,
      );
      final leafNode1 = builder(TreeBuildContext(currentLeafData, parentNode));
      final leafNode2 = builder(TreeBuildContext(currentLeafData, parentNode));

      expect(identical(leafNode1.dataProvider, leafNode2.dataProvider), isFalse);
    });
  });

  group('buildInterior', () {
    var nodeBuilder = interiorBuilder(
      key: stateKey,
      createState: (key) => state,
      children: [
        leafBuilder(key: childState1Key, createState: (key) => childState1),
        leafBuilder(key: childState2Key, createState: (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build an interior node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var interiorNode = nodeBuilder(buildCtx);

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

      var nodeBuilder = interiorBuilder(
        createState: (key) => state,
        children: [
          leafBuilder(key: childState1Key, createState: (key) => childState1),
          leafBuilder(key: childState2Key, createState: (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var interiorNode = nodeBuilder(buildCtx);
      expect(interiorNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test("should add node to context", () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var interiorNode = nodeBuilder(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(interiorNode));
      interiorNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('buildDataInterior', () {
    test('should build a data leaf node', () {
      SimpleDataState theState;
      final buildCtx = TreeBuildContext(currentLeafData, parentNode);
      final builder = dataInteriorBuilder(
          key: stateKey,
          createState: (key) {
            return theState = SimpleDataState();
          },
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [leafBuilder(createState: (_) => new SimpleState())]);
      final interiorNode = builder(buildCtx);

      expect(interiorNode, isNotNull);
      expect(interiorNode.key, equals(stateKey));
      expect(interiorNode.isInterior, isTrue);
      expect(interiorNode.state(), same(theState));
      expect(interiorNode.parent, same(parentNode));
      expect(interiorNode.children.length, equals(1));
    });

    test('should create new data provider', () {
      final builder = dataInteriorBuilder(
          key: stateKey,
          createState: (key) => SimpleDataState(),
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [leafBuilder(createState: (_) => new SimpleState())]);
      final node1 = builder(TreeBuildContext(currentLeafData, parentNode));
      final node2 = builder(TreeBuildContext(currentLeafData, parentNode));

      expect(identical(node1.dataProvider, node2.dataProvider), isFalse);
    });
  });

  group('buildRoot', () {
    var buildRoot = rootBuilder(
      key: stateKey,
      createState: (key) => state,
      children: [
        leafBuilder(key: childState1Key, createState: (key) => childState1),
        leafBuilder(key: childState2Key, createState: (key) => childState2),
      ],
      initialChild: (_) => childState1Key,
    );

    test('should build a root node', () {
      var buildCtx = TreeBuildContext(null);

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
      var buildCtx = TreeBuildContext(null);

      var buildRoot = rootBuilder(
        createState: (key) => state,
        children: [
          leafBuilder(key: childState1Key, createState: (key) => childState1),
          leafBuilder(key: childState2Key, createState: (key) => childState2),
        ],
        initialChild: (_) => childState1Key,
      );

      var rootNode = buildRoot(buildCtx);
      expect(rootNode.key, equals(StateKey.forState<SimpleState>()));
    });

    test('should throw if built with a parent node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);
      expect(() => buildRoot(buildCtx), throwsArgumentError);
    });

    test('should add node to context', () {
      var buildCtx = TreeBuildContext(null);

      var rootNode = buildRoot(buildCtx);

      expect(buildCtx.nodes[stateKey], equals(rootNode));
      rootNode.children.forEach((c) {
        expect(buildCtx.nodes[c.key], equals(c));
      });
    });
  });

  group('buildDataRoot', () {
    test('should build a data leaf node', () {
      SimpleDataState theState;
      final buildCtx = TreeBuildContext(currentLeafData, null);
      final builder = dataRootBuilder(
          key: stateKey,
          createState: (key) {
            return theState = SimpleDataState();
          },
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [leafBuilder(createState: (_) => new SimpleState())]);
      final rootNode = builder(buildCtx);

      expect(rootNode, isNotNull);
      expect(rootNode.key, equals(stateKey));
      expect(rootNode.isRoot, isTrue);
      expect(rootNode.state(), same(theState));
      expect(rootNode.parent, isNull);
      expect(rootNode.children.length, equals(1));
    });

    test('should create new data provider', () {
      final builder = dataRootBuilder(
          key: stateKey,
          createState: (key) => SimpleDataState(),
          createProvider: SimpleDataA.dataProvider,
          initialChild: (_) => StateKey.forState<SimpleState>(),
          children: [leafBuilder(createState: (_) => new SimpleState())]);
      final node1 = builder(TreeBuildContext(currentLeafData, null));
      final node2 = builder(TreeBuildContext(currentLeafData, null));

      expect(identical(node1.dataProvider, node2.dataProvider), isFalse);
    });
  });

  group('buildFinal', () {
    test('should build a final node', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var buildFinal = finalBuilder(key: finaKey, createState: (key) => finalState);
      var finalNode = buildFinal(buildCtx);

      expect(finalNode, isNotNull);
      expect(finalNode.key, equals(finaKey));
      expect(finalNode.isFinal, isTrue);
      expect(finalNode.state(), same(finalState));
      expect(finalNode.parent, same(parentNode));
      expect(finalNode.children, isEmpty);
    });

    test('should build a leaf node with type-based state key', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var buildFinal = finalBuilder(createState: (key) => finalState);
      var finalNode = buildFinal(buildCtx);

      expect(finalNode.key, equals(StateKey.forState<SimpleFinalState>()));
    });

    test('should add node to context', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);

      var buildFinal = finalBuilder(key: finaKey, createState: (key) => finalState);
      var finalNode = buildFinal(buildCtx);

      expect(buildCtx.nodes[finaKey], equals(finalNode));
    });
  });

  group('BuildContext', () {
    test('should throw if node with duplicate key is added', () {
      var buildCtx = TreeBuildContext(currentLeafData, parentNode);
      var key = StateKey.named("Foo");
      var builder = leafBuilder(key: key, createState: (key) => state);

      builder(buildCtx);

      expect(() => builder(buildCtx), throwsArgumentError);
    });
  });
}
