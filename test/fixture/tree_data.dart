import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/tree_state.dart';
part 'tree_data.g.dart';

@JsonSerializable()
class SimpleDataA {
  String name;
  int age;
  Map<String, dynamic> toJson() => _$SimpleDataAToJson(this);
  static DataProvider<SimpleDataA> jsonProvider() => DataProvider.json(
        () => SimpleDataA(),
        _$SimpleDataAToJson,
        _$SimpleDataAFromJson,
      );
}

@JsonSerializable()
class SimpleDataB {
  String productNumber;
  Map<String, dynamic> toJson() => _$SimpleDataBToJson(this);
  static DataProvider<SimpleDataB> jsonProvider() => DataProvider.json(
        () => SimpleDataB(),
        _$SimpleDataBToJson,
        _$SimpleDataBFromJson,
      );
}

@JsonSerializable()
class SimpleDataC {
  String modelYear;
  Map<String, dynamic> toJson() => _$SimpleDataCToJson(this);
  static DataProvider<SimpleDataC> jsonProvider() => DataProvider.json(
        () => SimpleDataC(),
        _$SimpleDataCToJson,
        _$SimpleDataCFromJson,
      );
}

@JsonSerializable()
class PlayerData {
  String playerName;
  List<HiScore> hiScores;
  Map<String, dynamic> toJson() => _$PlayerDataToJson(this);
  static DataProvider<PlayerData> jsonProvider() => DataProvider.json(
        () => PlayerData(),
        _$PlayerDataToJson,
        _$PlayerDataFromJson,
      );
}

@JsonSerializable()
class SpecialPlayerData extends PlayerData {
  int startYear;
  Map<String, dynamic> toJson() => _$SpecialPlayerDataToJson(this);
  static DataProvider<SpecialPlayerData> jsonProvider() => DataProvider.json(
        () => SpecialPlayerData(),
        _$SpecialPlayerDataToJson,
        _$SpecialPlayerDataFromJson,
      );
}

@JsonSerializable()
class HiScore {
  String game;
  int score;
  HiScore();
  factory HiScore.fromJson(Map<String, dynamic> json) => _$HiScoreFromJson(json);
  Map<String, dynamic> toJson() => _$HiScoreToJson(this);
  static DataProvider<HiScore> jsonProvider() => DataProvider.json(
        () => HiScore(),
        _$HiScoreToJson,
        _$HiScoreFromJson,
      );
}
