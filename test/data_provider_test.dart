import 'package:async/async.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_helpers.dart';

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
}
