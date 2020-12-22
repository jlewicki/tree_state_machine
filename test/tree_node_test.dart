import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';
import 'fixture/data_tree.dart';
import 'fixture/tree_data.dart';
import 'matchers/matchers.dart';

void main() {
  group('TreeNode', () {
    group('lcaWith', () {
      test('should return least common ancestor', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node1 = sm.machine.nodes[r_a_a_1_key].node;
        var node2 = sm.machine.nodes[r_a_1_key].node;

        var lca = node1.lcaWith(node2);
        expect(lca, isNotNull);
        expect(lca.key, r_a_key);
      });

      test('should return the node when nodes are the same', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node1 = sm.machine.nodes[r_a_a_1_key].node;
        var lca = node1.lcaWith(node1);
        expect(lca, isNotNull);
        expect(lca.key, r_a_a_1_key);
      });
    });

    group('selfAndAncestors', () {
      test('should return self and ancestors', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var sAndA = node.selfAndAncestors().map((n) => n.key).toList();

        expect(sAndA, orderedEquals([r_a_a_1_key, r_a_a_key, r_a_key, r_key]));
      });
    });

    group('selfOrAncestorWithKey', () {
      test('should return self', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var match = node.selfOrAncestorWithKey(r_a_a_1_key);

        expect(match, same(node));
      });

      test('should return ancestor', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var match = node.selfOrAncestorWithKey(r_a_key);

        expect(match.key, equals(r_a_key));
      });

      test('should return null if no match', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var match = node.selfOrAncestorWithKey(r_b_key);

        expect(match, isNull);
      });
    });

    group('selfOrAncestorWithData', () {
      test('should return self', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var match = node.selfOrAncestorWithData<LeafData1>();

        expect(match, same(node));
      });

      test('should return ancestor', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var match = node.selfOrAncestorWithData<ImmutableData>();

        expect(match.key, equals(r_a_key));
      });

      test('should return null if no match', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var match = node.selfOrAncestorWithData<String>();

        expect(match, isNull);
      });
    });

    group('ancestors', () {
      test('should return ancestors', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        var sAndA = node.ancestors().map((n) => n.key).toList();

        expect(sAndA, orderedEquals([r_a_a_key, r_a_key, r_key]));
      });
    });

    group('dispose', () {
      test('should dispose data provider', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        await sm.start(r_a_a_1_key);

        sm.machine.currentNode.dispose();

        expect(() => sm.machine.currentNode.dataProvider().data, throwsDisposedError);
      });

      test('should not force evaluation of provider', () async {
        var sm = TestableTreeStateMachine(treeBuilder());
        var node = sm.machine.nodes[r_a_a_1_key].node;

        node.dispose();

        expect(node.lazyProvider.hasValue, isFalse);
      });
    });

    group('selfOrAncestorDataStream', () {
      var r_a_a_1_data = LeafData1()..counter = 10;
      var r_a_a_data = LeafDataBase()..name = 'jim';
      var r_a_data = ImmutableData((b) => b
        ..name = 'Dude'
        ..price = 8);
      var r_data = SpecialDataD()
        ..playerName = 'FOO'
        ..startYear = 2000
        ..hiScores.add(HiScore()
          ..game = 'foo'
          ..score = 10);
      var rootBuilder = treeBuilder(initialDataValues: {
        r_a_a_1_key: r_a_a_1_data,
        r_a_a_key: r_a_a_data,
        r_a_key: r_a_data,
        r_key: r_data,
      });

      test('should retrieve self or ancestor data with matching key', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var r_a_a_1_stream =
            sm.machine.currentNode.selfOrAncestorDataStream<LeafData1>(r_a_a_1_key);
        expect(r_a_a_1_stream.value, equals(r_a_a_1_data));
        var r_a_a_stream = sm.machine.currentNode.selfOrAncestorDataStream<LeafDataBase>(r_a_a_key);
        expect(r_a_a_stream.value, equals(r_a_a_data));
        var r_a_stream = sm.machine.currentNode.selfOrAncestorDataStream<ImmutableData>(r_a_key);
        expect(r_a_stream.value, equals(r_a_data));
        var r_stream = sm.machine.currentNode.selfOrAncestorDataStream<SpecialDataD>(r_key);
        expect(r_stream.value, equals(r_data));
      });

      test('should return null if key is not an active state', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var stream = sm.machine.currentNode.selfOrAncestorDataStream<LeafData2>(r_a_a_2_key);
        expect(stream, isNull);
      });

      test('should throw if key is an active state but wrong data type', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        expect(() => sm.machine.currentNode.selfOrAncestorDataStream<LeafData2>(r_a_a_1_key),
            throwsStateError);
      });

      test('should retrieve self or ancestor data with matching type', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var r_a_a_1_stream = sm.machine.currentNode.selfOrAncestorDataStream<LeafData1>();
        expect(r_a_a_1_stream.value, equals(r_a_a_1_data));
        var r_a_a_stream = sm.machine.currentNode.selfOrAncestorDataStream<LeafDataBase>();
        expect(r_a_a_stream.value, equals(r_a_a_data));
        var r_a_stream = sm.machine.currentNode.selfOrAncestorDataStream<ImmutableData>();
        expect(r_a_stream.value, equals(r_a_data));
        var r_stream = sm.machine.currentNode.selfOrAncestorDataStream<SpecialDataD>();
        expect(r_stream.value, equals(r_data));
      });

      test('should return null if data type does not match an active state', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var r_a_a_1_stream = sm.machine.currentNode.selfOrAncestorDataStream<LeafData2>();
        expect(r_a_a_1_stream, isNull);
      });
    });
  });
}
