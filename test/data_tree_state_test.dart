import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'fixture/tree_data.dart';

class SimpleDataState extends EmptyDataTreeState<SimpleDataA> {}

void main() {
  group('DataProvider', () {
    group('data', () {
      test('should create data instance on demand', () {
        final provider = SimpleDataA.jsonProvider();
        expect(provider.data, isNotNull);
      });
    });

    group('encode', () {
      test('should encode data using codec', () {
        final provider = SimpleDataA.jsonProvider();
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final expected = provider.encoder(provider.data);
        final actual = provider.encode();

        expect(actual, isA<Map<String, dynamic>>());
        expect(
            (actual as Map<String, dynamic>).entries,
            pairwiseCompare(
                expected.entries,
                (aEntry, eEntry) => aEntry.key == eEntry.key && aEntry.value == eEntry.value,
                'entries are the same'));
      });
    });

    group('decodeInto', () {
      test('should update data', () {
        final provider = SimpleDataA.jsonProvider();
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final newData = SimpleDataA()
          ..name = 'Jim'
          ..age = 30;

        provider.decodeInto(newData.toJson());

        expect(provider.data.name, equals('Jim'));
        expect(provider.data.age, equals(30));
      });
    });
  });
}
