// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleData _$SimpleDataFromJson(Map<String, dynamic> json) {
  return SimpleData()
    ..name = json['name'] as String
    ..age = json['age'] as int;
}

Map<String, dynamic> _$SimpleDataToJson(SimpleData instance) =>
    <String, dynamic>{
      'name': instance.name,
      'age': instance.age,
    };

PlayerData _$PlayerDataFromJson(Map<String, dynamic> json) {
  return PlayerData()
    ..playerName = json['playerName'] as String
    ..hiScores = (json['hiScores'] as List)
        ?.map((e) =>
            e == null ? null : HiScore.fromJson(e as Map<String, dynamic>))
        ?.toList();
}

Map<String, dynamic> _$PlayerDataToJson(PlayerData instance) =>
    <String, dynamic>{
      'playerName': instance.playerName,
      'hiScores': instance.hiScores,
    };

HiScore _$HiScoreFromJson(Map<String, dynamic> json) {
  return HiScore()
    ..game = json['game'] as String
    ..score = json['score'] as int;
}

Map<String, dynamic> _$HiScoreToJson(HiScore instance) => <String, dynamic>{
      'game': instance.game,
      'score': instance.score,
    };
