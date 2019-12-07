import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'fixture/tree_data.dart';

class SimpleDataState extends EmptyDataTreeState<SimpleDataA> {}

void main() {
  group('DataProvider', () {
    group('data', () {
      test('should create data instance on demand', () {
        final provider = SimpleDataA.dataProvider();
        expect(provider.data, isNotNull);
      });
    });

    group('encode', () {
      test('should encode data using encoder', () {
        final provider = SimpleDataA.dataProvider();
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final expected = provider.encoder(provider.data) as Map<String, dynamic>;
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
        final provider = SimpleDataA.dataProvider();
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

    group('replace', () {
      test('shoud replace data with new value', () {
        final provider = SimpleDataA.dataProvider();
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final newData = SimpleDataA()
          ..name = 'Jim'
          ..age = 30;

        provider.replace(() => newData);

        expect(provider.data.name, equals('Jim'));
        expect(provider.data.age, equals(30));
      });
    });

    group('replace', () {
      test('shoud replace data with new value', () {
        final provider = SimpleDataA.dataProvider();
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final newData = SimpleDataA()
          ..name = 'Jim'
          ..age = 30;

        provider.replace(() => newData);

        expect(provider.data.name, equals('Jim'));
        expect(provider.data.age, equals(30));
      });
    });
  });

  group('LeafDataProvider', () {
    group('encode', () {
      test('should return null', () {
        expect(LeafDataBase.dataProvider().encode(), isNull);
      });
    });

    group('replace', () {
      test('should throw', () {
        expect(() => LeafDataBase.dataProvider().replace(() => null), throwsUnsupportedError);
      });
    });

    group('data', () {
      test('should get data from leaf accessor', () {
        final provider = LeafDataBase.dataProvider();
        final leafData = LeafData1();
        provider.initializeLeafDataAccessor(() => leafData);

        expect(provider.data, same(leafData));
      });

      test('should get throw if leaf data is not compatible with D', () {
        final provider = LeafDataBase.dataProvider();
        final leafData = SimpleDataC();
        provider.initializeLeafDataAccessor(() => leafData);

        expect(() => provider.data, throwsStateError);
      });
    });
  });
}
