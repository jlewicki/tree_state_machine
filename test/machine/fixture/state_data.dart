import 'package:json_annotation/json_annotation.dart';
import 'package:built_value/built_value.dart';
import 'package:built_value/serializer.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

part 'state_data.g.dart';

@JsonSerializable()
class SimpleDataD {
  String? playerName;
  List<HiScore> hiScores = [];
  static StateDataCodec<SimpleDataD> serializer = StateDataCodec.json(
    _$SimpleDataDToJson,
    _$SimpleDataDFromJson,
  );
}

@JsonSerializable()
class SpecialDataD extends SimpleDataD {
  int? startYear;
  static StateDataCodec<SpecialDataD> codec = StateDataCodec.json(
    _$SpecialDataDToJson,
    _$SpecialDataDFromJson,
  );
}

@JsonSerializable()
class HiScore {
  String game;
  int score;
  HiScore(this.game, this.score);
  factory HiScore.fromJson(Map<String, dynamic> json) => _$HiScoreFromJson(json);
  Map<String, dynamic> toJson() => _$HiScoreToJson(this);
}

@JsonSerializable()
class LeafDataBase {
  String? name;
  static StateDataCodec<LeafDataBase> codec = StateDataCodec.json(
    _$LeafDataBaseToJson,
    _$LeafDataBaseFromJson,
  );
}

@JsonSerializable()
class LeafData1 {
  int? counter;
  static StateDataCodec<LeafData1> codec = StateDataCodec.json(
    _$LeafData1ToJson,
    _$LeafData1FromJson,
  );
}

@JsonSerializable()
class LeafData2 {
  String? label;
  static StateDataCodec<LeafData2> codec = StateDataCodec.json(
    _$LeafData2ToJson,
    _$LeafData2FromJson,
  );
}

@JsonSerializable()
class ReadOnlyData {
  final String _name;
  final int _counter;
  String get name => _name;
  int get counter => _counter;
  ReadOnlyData(String name, int counter)
      : _name = name,
        _counter = counter;
  static StateDataCodec<ReadOnlyData> codec = StateDataCodec.json(
    _$ReadOnlyDataToJson,
    _$ReadOnlyDataFromJson,
  );
}

abstract class ImmutableData implements Built<ImmutableData, ImmutableDataBuilder> {
  String get name;
  int get price;
  factory ImmutableData([dynamic Function(ImmutableDataBuilder b) updates]) = _$ImmutableData;
  static StateDataCodec codec = StateDataCodec<ImmutableData>(
    (o) => serializers.serializeWith(_$immutableDataSerializer, o),
    (o) => serializers.deserializeWith(_$immutableDataSerializer, o),
  );
  static Serializer<ImmutableData> get serializer => _$immutableDataSerializer;
  ImmutableData._();
}

@SerializersFor([ImmutableData])
final Serializers serializers = _$serializers;
