// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_state_machine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_StateData _$_StateDataFromJson(Map<String, dynamic> json) {
  return _StateData(
    json['key'] as String,
    json['encodedData'],
    json['dataVersion'] as String,
  );
}

Map<String, dynamic> _$_StateDataToJson(_StateData instance) =>
    <String, dynamic>{
      'key': instance.key,
      'encodedData': instance.encodedData,
      'dataVersion': instance.dataVersion,
    };

_StateTreeData _$_StateTreeDataFromJson(Map<String, dynamic> json) {
  return _StateTreeData(
    json['version'] as String,
    (json['stateData'] as List)
        ?.map((e) =>
            e == null ? null : _StateData.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$_StateTreeDataToJson(_StateTreeData instance) =>
    <String, dynamic>{
      'version': instance.version,
      'stateData': instance.stateData,
    };
