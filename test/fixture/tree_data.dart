import 'package:json_annotation/json_annotation.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:tree_state_machine/src/data_provider.dart';

part 'tree_data.g.dart';

@JsonSerializable()
class SimpleDataA {
  String name;
  int age;
  Map<String, dynamic> toJson() => _$SimpleDataAToJson(this);
  static OwnedDataProvider<SimpleDataA> dataProvider([SimpleDataA initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? SimpleDataA(),
        _$SimpleDataAToJson,
        _$SimpleDataAFromJson,
      );
}

@JsonSerializable()
class SimpleDataB {
  String productNumber;
  Map<String, dynamic> toJson() => _$SimpleDataBToJson(this);
  static OwnedDataProvider<SimpleDataB> dataProvider([SimpleDataB initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? SimpleDataB(),
        _$SimpleDataBToJson,
        _$SimpleDataBFromJson,
      );
}

@JsonSerializable()
class SimpleDataC {
  String modelYear;
  Map<String, dynamic> toJson() => _$SimpleDataCToJson(this);
  static OwnedDataProvider<SimpleDataC> dataProvider([SimpleDataC initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? SimpleDataC(),
        _$SimpleDataCToJson,
        _$SimpleDataCFromJson,
      );
}

@JsonSerializable()
class SimpleDataD {
  String playerName;
  List<HiScore> hiScores = [];
  Map<String, dynamic> toJson() => _$SimpleDataDToJson(this);
  static OwnedDataProvider<SimpleDataD> dataProvider([SimpleDataD initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? SimpleDataD(),
        _$SimpleDataDToJson,
        _$SimpleDataDFromJson,
      );
}

@JsonSerializable()
class SpecialDataD extends SimpleDataD {
  int startYear;
  Map<String, dynamic> toJson() => _$SpecialDataDToJson(this);
  static OwnedDataProvider<SpecialDataD> dataProvider([SpecialDataD initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? SpecialDataD(),
        _$SpecialDataDToJson,
        _$SpecialDataDFromJson,
      );
}

@JsonSerializable()
class HiScore {
  String game;
  int score;
  HiScore();
  factory HiScore.fromJson(Map<String, dynamic> json) => _$HiScoreFromJson(json);
  Map<String, dynamic> toJson() => _$HiScoreToJson(this);
  static OwnedDataProvider<HiScore> dataProvider() => OwnedDataProvider.json(
        () => HiScore(),
        _$HiScoreToJson,
        _$HiScoreFromJson,
      );
}

@JsonSerializable()
class LeafDataBase {
  String name;
  Map<String, dynamic> toJson() => _$LeafDataBaseToJson(this);
  static OwnedDataProvider<LeafDataBase> dataProvider([LeafDataBase initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? LeafDataBase(),
        _$LeafDataBaseToJson,
        _$LeafDataBaseFromJson,
      );
}

@JsonSerializable()
// class LeafData1 extends LeafDataBase {
class LeafData1 {
  int counter;
  Map<String, dynamic> toJson() => _$LeafData1ToJson(this);
  static OwnedDataProvider<LeafData1> dataProvider([LeafData1 initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? LeafData1(),
        _$LeafData1ToJson,
        _$LeafData1FromJson,
      );
}

@JsonSerializable()
// class LeafData2 extends LeafDataBase {
class LeafData2 {
  String label;
  Map<String, dynamic> toJson() => _$LeafData2ToJson(this);
  static OwnedDataProvider<LeafData2> dataProvider([LeafData2 initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? LeafData2(),
        _$LeafData2ToJson,
        _$LeafData2FromJson,
      );
}

@JsonSerializable()
class ReadOnlyData {
  String _name;
  int _counter;
  String get name => _name;
  int get counter => _counter;
  ReadOnlyData(String name, int counter) {
    _name = name;
    _counter = counter;
  }
  Map<String, dynamic> toJson() => _$ReadOnlyDataToJson(this);
  static OwnedDataProvider<ReadOnlyData> dataProvider([ReadOnlyData initialValue]) =>
      OwnedDataProvider.json(
        () => initialValue ?? ReadOnlyData('', 1),
        _$ReadOnlyDataToJson,
        _$ReadOnlyDataFromJson,
      );
}

abstract class ImmutableData implements Built<ImmutableData, ImmutableDataBuilder> {
  String get name;
  int get price;
  factory ImmutableData([updates(ImmutableDataBuilder b)]) = _$ImmutableData;
  static OwnedDataProvider<ImmutableData> dataProvider([ImmutableData initialValue]) =>
      OwnedDataProvider.encodable(
        () =>
            initialValue ??
            ImmutableData((b) => b
              ..name = ''
              ..price = 1),
        (o) => serializers.serializeWith(_$immutableDataSerializer, o),
        (o) => serializers.deserializeWith(_$immutableDataSerializer, o),
      );

  static Serializer<ImmutableData> get serializer => _$immutableDataSerializer;
  ImmutableData._();
}

@SerializersFor([ImmutableData])
final Serializers serializers = _$serializers;
