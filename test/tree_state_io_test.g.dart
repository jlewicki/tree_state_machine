// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_state_io_test.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SomeData _$SomeDataFromJson(Map<String, dynamic> json) {
  return SomeData()
    ..count = json['count'] as int
    ..itemNumber = json['itemNumber'] as int
    ..isRushed = json['isRushed'] as bool;
}

Map<String, dynamic> _$SomeDataToJson(SomeData instance) => <String, dynamic>{
      'count': instance.count,
      'itemNumber': instance.itemNumber,
      'isRushed': instance.isRushed,
    };

OtherData _$OtherDataFromJson(Map<String, dynamic> json) {
  return OtherData()
    ..playerName = json['playerName'] as String
    ..hiScores = (json['hiScores'] as List)
        ?.map((e) =>
            e == null ? null : HiScore.fromJson(e as Map<String, dynamic>))
        ?.toList();
}

Map<String, dynamic> _$OtherDataToJson(OtherData instance) => <String, dynamic>{
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
