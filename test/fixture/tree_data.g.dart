// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_data.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleDataA _$SimpleDataAFromJson(Map<String, dynamic> json) {
  return SimpleDataA()
    ..name = json['name'] as String
    ..age = json['age'] as int;
}

Map<String, dynamic> _$SimpleDataAToJson(SimpleDataA instance) =>
    <String, dynamic>{
      'name': instance.name,
      'age': instance.age,
    };

SimpleDataB _$SimpleDataBFromJson(Map<String, dynamic> json) {
  return SimpleDataB()..productNumber = json['productNumber'] as String;
}

Map<String, dynamic> _$SimpleDataBToJson(SimpleDataB instance) =>
    <String, dynamic>{
      'productNumber': instance.productNumber,
    };

SimpleDataC _$SimpleDataCFromJson(Map<String, dynamic> json) {
  return SimpleDataC()..modelYear = json['modelYear'] as String;
}

Map<String, dynamic> _$SimpleDataCToJson(SimpleDataC instance) =>
    <String, dynamic>{
      'modelYear': instance.modelYear,
    };

SimpleDataD _$SimpleDataDFromJson(Map<String, dynamic> json) {
  return SimpleDataD()
    ..playerName = json['playerName'] as String
    ..hiScores = (json['hiScores'] as List)
        ?.map((e) =>
            e == null ? null : HiScore.fromJson(e as Map<String, dynamic>))
        ?.toList();
}

Map<String, dynamic> _$SimpleDataDToJson(SimpleDataD instance) =>
    <String, dynamic>{
      'playerName': instance.playerName,
      'hiScores': instance.hiScores,
    };

SpecialDataD _$SpecialDataDFromJson(Map<String, dynamic> json) {
  return SpecialDataD()
    ..playerName = json['playerName'] as String
    ..hiScores = (json['hiScores'] as List)
        ?.map((e) =>
            e == null ? null : HiScore.fromJson(e as Map<String, dynamic>))
        ?.toList()
    ..startYear = json['startYear'] as int;
}

Map<String, dynamic> _$SpecialDataDToJson(SpecialDataD instance) =>
    <String, dynamic>{
      'playerName': instance.playerName,
      'hiScores': instance.hiScores,
      'startYear': instance.startYear,
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

LeafData1 _$LeafData1FromJson(Map<String, dynamic> json) {
  return LeafData1()
    ..name = json['name'] as String
    ..counter = json['counter'] as int;
}

Map<String, dynamic> _$LeafData1ToJson(LeafData1 instance) => <String, dynamic>{
      'name': instance.name,
      'counter': instance.counter,
    };

LeafData2 _$LeafData2FromJson(Map<String, dynamic> json) {
  return LeafData2()
    ..name = json['name'] as String
    ..label = json['label'] as String;
}

Map<String, dynamic> _$LeafData2ToJson(LeafData2 instance) => <String, dynamic>{
      'name': instance.name,
      'label': instance.label,
    };

ReadOnlyData _$ReadOnlyDataFromJson(Map<String, dynamic> json) {
  return ReadOnlyData(
    json['name'] as String,
  );
}

Map<String, dynamic> _$ReadOnlyDataToJson(ReadOnlyData instance) =>
    <String, dynamic>{
      'name': instance.name,
    };
