import 'package:json_annotation/json_annotation.dart';
part 'tree_state_io_test.g.dart';

@JsonSerializable()
class SomeData {
  int count;
  int itemNumber;
  bool isRushed;
}

@JsonSerializable()
class OtherData {
  String playerName;
  List<HiScore> hiScores;
}

@JsonSerializable()
class HiScore {
  String game;
  int score;
  HiScore();
  factory HiScore.fromJson(Map<String, dynamic> json) => _$HiScoreFromJson(json);
}

void main() {
//
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
