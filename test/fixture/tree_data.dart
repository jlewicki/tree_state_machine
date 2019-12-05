import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/tree_node.dart';
part 'tree_data.g.dart';

@JsonSerializable()
class SimpleDataA {
  String name;
  int age;
  Map<String, dynamic> toJson() => _$SimpleDataAToJson(this);
  static OwnedDataProvider<SimpleDataA> jsonProvider() => OwnedDataProvider(
        () => SimpleDataA(),
        _$SimpleDataAToJson,
        _$SimpleDataAFromJson,
      );
}

@JsonSerializable()
class SimpleDataB {
  String productNumber;
  Map<String, dynamic> toJson() => _$SimpleDataBToJson(this);
  static OwnedDataProvider<SimpleDataB> jsonProvider() => OwnedDataProvider(
        () => SimpleDataB(),
        _$SimpleDataBToJson,
        _$SimpleDataBFromJson,
      );
}

@JsonSerializable()
class SimpleDataC {
  String modelYear;
  Map<String, dynamic> toJson() => _$SimpleDataCToJson(this);
  static OwnedDataProvider<SimpleDataC> jsonProvider() => OwnedDataProvider(
        () => SimpleDataC(),
        _$SimpleDataCToJson,
        _$SimpleDataCFromJson,
      );
}

@JsonSerializable()
class SimpleDataD {
  String playerName;
  List<HiScore> hiScores = [];
  Map<String, dynamic> toJson() => _$SimpleDataDToJson(this);
  static OwnedDataProvider<SimpleDataD> jsonProvider() => OwnedDataProvider(
        () => SimpleDataD(),
        _$SimpleDataDToJson,
        _$SimpleDataDFromJson,
      );
}

@JsonSerializable()
class SpecialDataD extends SimpleDataD {
  int startYear;
  Map<String, dynamic> toJson() => _$SpecialDataDToJson(this);
  static OwnedDataProvider<SpecialDataD> jsonProvider() => OwnedDataProvider(
        () => SpecialDataD(),
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
  static OwnedDataProvider<HiScore> jsonProvider() => OwnedDataProvider(
        () => HiScore(),
        _$HiScoreToJson,
        _$HiScoreFromJson,
      );
}
