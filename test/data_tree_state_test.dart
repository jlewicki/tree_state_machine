import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'fixture/tree_data.dart';

class SimpleDataState extends EmptyDataTreeState<SimpleDataA> {
  SimpleDataState() : super(SimpleDataA.jsonProvider());
}

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

  group('DataTreeState', () {
    test('should create data instance on demand', () {
      final state = SimpleDataState();
      expect(state.data, isNotNull);
    });
  });
}

//  test('io stuff', () async {
// //     var keyedByType = <Type, dynamic>{
// //       _TypeLiteral<String>().type: 'stringData',
// //       _TypeLiteral<int>().type: 'intData',
// //     };

// //     final controller = StreamController<Object>.broadcast();
// //     final map = <String, dynamic>{'name': 'jim', 'age': 10};
// //     final toSave = [1, 'hello'];

// // // https://github.com/dart-lang/sdk/issues/36351
// //     //var outputStream = Stream.fromIterable(toSave).transform(json.encoder).transform(utf8.encoder);
// //     var outputStream =
// //         Stream.fromIterable(toSave).map(json.encoder.convert).transform(utf8.encoder);
// //     var sink = File(joinAll(['D:\\', 'temp', 'json.data'])).openWrite();
// //     await sink.addStream(outputStream);
// //     await sink.close();

// //     // List<Object> items = [];
// //     // //var jsonStream = controller.stream;
// //     // var jsonStream = Stream.fromIterable(<Object>[1, 2]).transform(json.encoder);
// //     // //var jsonStream = controller.stream.transform(json.encoder);
// //     // // var jsonQ = StreamQueue(jsonStream);
// //     // var forEachFuture = jsonStream.toList();
// //     // var foo = await forEachFuture;
// //     // expect(foo.length, greaterThanOrEqualTo(2));
// //     // // controller.add(1);
// //     // // controller.add(map);
// //     // await Future.delayed(Duration(milliseconds: 59));
// //     // await Future.wait([controller.close(), forEachFuture]);
// //     // expect(items.isEmpty, isFalse);
//   });

// class _TypeLiteral<T> {
//   Type get type => T;
// }

// abstract class StateData {}

// abstract class JsonStateData2<D extends JsonStateData2<D>> {}

// class JsonDataCodec<D extends StateData> {
//   final Map<String, dynamic> Function(D data) _toJson;
//   final D Function(Map<String, dynamic> json) _fromJson;

//   JsonDataCodec(this._toJson, this._fromJson);

//   Map<String, dynamic> toJson(D data) {
//     return _toJson(data);
//   }

//   D fromJson(Map<String, dynamic> json) {
//     return _fromJson(json);
//   }
// }

// abstract class HasStateData<D extends StateData> {
//   D stateData;
// }

// abstract class HasJsonDataCodec<D extends StateData> {
//   JsonDataCodec<D> get codec;
// }

// abstract class DataTreeState<D extends StateData> extends TreeState
//     implements HasStateData<D>, HasJsonDataCodec<D> {
//   D stateData;
// }
