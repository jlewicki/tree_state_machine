import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/tree_node.dart';
part 'tree_data.g.dart';

@JsonSerializable()
class SimpleDataA {
  String name;
  int age;
  Map<String, dynamic> toJson() => _$SimpleDataAToJson(this);
  static OwnedDataProvider<SimpleDataA> dataProvider([SimpleDataA initialValue]) =>
      OwnedDataProvider(
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
      OwnedDataProvider(
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
      OwnedDataProvider(
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
      OwnedDataProvider(
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
      OwnedDataProvider(
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
  static OwnedDataProvider<HiScore> dataProvider() => OwnedDataProvider(
        () => HiScore(),
        _$HiScoreToJson,
        _$HiScoreFromJson,
      );
}

class LeafDataBase {
  String name;
  static LeafDataProvider<LeafDataBase> dataProvider() => LeafDataProvider();
}

@JsonSerializable()
class LeafData1 extends LeafDataBase {
  int counter;
  Map<String, dynamic> toJson() => _$LeafData1ToJson(this);
  static OwnedDataProvider<LeafData1> dataProvider([LeafData1 initialValue]) => OwnedDataProvider(
        () => initialValue ?? LeafData1(),
        _$LeafData1ToJson,
        _$LeafData1FromJson,
      );
}

@JsonSerializable()
class LeafData2 extends LeafDataBase {
  String label;
  Map<String, dynamic> toJson() => _$LeafData2ToJson(this);
  static OwnedDataProvider<LeafData2> dataProvider([LeafData2 initialValue]) => OwnedDataProvider(
        () => initialValue ?? LeafData2(),
        _$LeafData2ToJson,
        _$LeafData2FromJson,
      );
}
