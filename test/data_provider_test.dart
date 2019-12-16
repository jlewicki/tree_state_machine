import 'package:async/async.dart';
import 'package:rxdart/rxdart.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/src/helpers.dart';

import 'fixture/tree_data.dart';

class SimpleDataState extends EmptyDataTreeState<SimpleDataA> {}

void main() {
  group('OwnedDataProvider', () {
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
      test('should replace data with new value', () {
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

      test('should emit on stream', () async {
        final provider = SimpleDataA.dataProvider();
        final q = StreamQueue(provider.dataStream);
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final newData = SimpleDataA()
          ..name = 'Jim'
          ..age = 30;

        provider.replace(() => newData);
        final future = q.next;
        final qItems = await Future.wait([future]);

        final emitted = qItems[0];
        expect(emitted, same(newData));
      });
    });
    group('update', () {
      test('should update data', () async {
        final provider = SimpleDataA.dataProvider();
        provider.data.name = 'Bill';
        provider.data.age = 25;

        provider.update(() => provider.data
          ..name = 'Jim'
          ..age = 30);

        expect(provider.data.name, 'Jim');
        expect(provider.data.age, equals(30));
      });

      test('should emit on stream', () async {
        final provider = SimpleDataA.dataProvider();
        final q = StreamQueue(provider.dataStream);
        provider.data.name = 'Bill';
        provider.data.age = 25;

        final future = q.next;
        provider.update(() => provider.data
          ..name = 'Jim'
          ..age = 30);
        final qItems = await Future.wait([future]);

        final emitted = qItems[0];
        expect(emitted.name, 'Jim');
        expect(emitted.age, equals(30));
      });
    });

    group('dispose', () {
      test('should close stream', () async {
        final provider = SimpleDataA.dataProvider();
        final q = StreamQueue(provider.dataStream);
        await q.skip(1); // Skip 1 because current value is always emitted.

        provider.dispose();

        var hasNext = await q.hasNext;
        expect(hasNext, isFalse);
      });
    });
  });

  group('CurrentLeafDataProvider', () {
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
      test('should get data from leaf accessor', () async {
        final provider = LeafDataBase.dataProvider();
        final leafDataProvider = LeafData1.dataProvider();
        provider.initializeLeafData(leafDataProvider);
        expect(provider.data, same(leafDataProvider.data));
      });

      test('should get throw if leaf data is not compatible with D', () {
        final provider = LeafDataBase.dataProvider();
        final leafData = SimpleDataC();
        provider.initializeLeafData(DelegateObservableData(getData: () => leafData));

        expect(() => provider.data, throwsStateError);
      });
    });

    group('update', () {
      test('should update data', () async {
        final leafProvider = LeafData1.dataProvider();
        leafProvider.data.name = 'Bill';
        leafProvider.data.counter = 25;

        final provider = LeafDataBase.dataProvider();
        provider.initializeLeafData(leafProvider);

        provider.update(() => provider.data.name = 'Jim');

        expect(provider.data.name, equals('Jim'));
        expect(leafProvider.data.name, equals('Jim'));
        expect(leafProvider.data.counter, equals(25));
      });

      test('should emit on stream', () async {
        final leafProvider = LeafData1.dataProvider();
        leafProvider.data.name = 'Bill';
        leafProvider.data.counter = 25;

        final provider = LeafDataBase.dataProvider();
        provider.initializeLeafData(leafProvider);
        final q = StreamQueue(provider.dataStream);

        final future = q.next;
        provider.update(() => provider.data.name = 'Jim');

        final qItems = await Future.wait([future]);

        final emitted = qItems[0];
        expect(emitted.name, 'Jim');
      });
    });

    group('dispose', () {
      test('should close stream', () async {
        final leafProvider = LeafData1.dataProvider();
        leafProvider.data.name = 'Bill';
        leafProvider.data.counter = 25;

        final provider = LeafDataBase.dataProvider();
        provider.initializeLeafData(leafProvider);
        final q = StreamQueue(provider.dataStream);
        // Skip 1 because current value is always sent to stream by BehaviorSubject, and we don't
        // care about that value for the purposes of this test.
        q.skip(1);

        provider.dispose();

        var hasNext = await q.hasNext;
        expect(hasNext, isFalse);
      });

      test('BehaviorSubject test', () async {
        final subject = BehaviorSubject<int>();
        subject.add(1);

        int count = 0;
        subject.listen((d) {
          count = count + 1;
        });
        await 0;
        subject.close();
        await 0;
        expect(count, equals(1));
      });
    });
  });
}