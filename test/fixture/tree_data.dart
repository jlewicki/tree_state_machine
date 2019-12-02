import 'package:json_annotation/json_annotation.dart';
import 'package:tree_state_machine/src/tree_state.dart';
part 'tree_data.g.dart';

@JsonSerializable()
class SimpleData {
  String name;
  int age;
  Map<String, dynamic> toJson() => _$SimpleDataToJson(this);
  static DataProvider<SimpleData> jsonProvider() => DataProvider.json(
        () => SimpleData(),
        _$SimpleDataToJson,
        _$SimpleDataFromJson,
      );
}

@JsonSerializable()
class PlayerData {
  String playerName;
  List<HiScore> hiScores;
  static DataProvider<PlayerData> jsonProvider() => DataProvider.json(
        () => PlayerData(),
        _$PlayerDataToJson,
        _$PlayerDataFromJson,
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
