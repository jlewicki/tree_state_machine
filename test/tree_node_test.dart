import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state_machine.dart';
import 'fixture/data_tree.dart';
import 'fixture/tree_data.dart';

void main() {
  group('TreeNode', () {
    group('dataStream', () {
      var r_a_a_1_data = LeafData1()
        ..name = 'Yo'
        ..counter = 10;
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
        r_a_key: r_a_data,
        r_key: r_data,
      });

      test('should retrieve self or ancestor data with matching key', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var r_a_a_1_stream = sm.machine.currentNode.dataStream<LeafData1>(r_a_a_1_key);
        expect(r_a_a_1_stream.value, equals(r_a_a_1_data));
        var r_a_a_stream = sm.machine.currentNode.dataStream<LeafDataBase>(r_a_a_key);
        expect(r_a_a_stream.value, equals(r_a_a_1_data));
        var r_a_stream = sm.machine.currentNode.dataStream<ImmutableData>(r_a_key);
        expect(r_a_stream.value, equals(r_a_data));
        var r_stream = sm.machine.currentNode.dataStream<SpecialDataD>(r_key);
        expect(r_stream.value, equals(r_data));
      });

      test('should return null if key is not an active state', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var stream = sm.machine.currentNode.dataStream<LeafData2>(r_a_a_2_key);
        expect(stream, isNull);
      });

      test('should throw if key is an active state but wrong data type', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        expect(() => sm.machine.currentNode.dataStream<LeafData2>(r_a_a_1_key), throwsStateError);
      });

      test('should retrieve self or ancestor data with matching type', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var r_a_a_1_stream = sm.machine.currentNode.dataStream<LeafData1>();
        expect(r_a_a_1_stream.value, equals(r_a_a_1_data));
        var r_a_a_stream = sm.machine.currentNode.dataStream<LeafDataBase>();
        expect(r_a_a_stream.value, equals(r_a_a_1_data));
        var r_a_stream = sm.machine.currentNode.dataStream<ImmutableData>();
        expect(r_a_stream.value, equals(r_a_data));
        var r_stream = sm.machine.currentNode.dataStream<SpecialDataD>();
        expect(r_stream.value, equals(r_data));
      });

      test('should return null if data type does not match an active state', () async {
        var sm = TestableTreeStateMachine(rootBuilder);
        await sm.start(r_a_a_1_key);

        var r_a_a_1_stream = sm.machine.currentNode.dataStream<LeafData2>();
        expect(r_a_a_1_stream, isNull);
      });
    });
  });
}
