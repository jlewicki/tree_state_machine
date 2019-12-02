// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_state_machine.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

EncodableState _$EncodableStateFromJson(Map<String, dynamic> json) {
  return EncodableState(
    json['key'] as String,
    json['encodedData'],
    json['dataVersion'] as String,
  );
}

Map<String, dynamic> _$EncodableStateToJson(EncodableState instance) => <String, dynamic>{
      'key': instance.key,
      'encodedData': instance.encodedData,
      'dataVersion': instance.dataVersion,
    };

EncodableTree _$EncodableTreeFromJson(Map<String, dynamic> json) {
  return EncodableTree(
    json['version'] as String,
    (json['encodableStates'] as List)
        ?.map((e) => e == null ? null : EncodableState.fromJson(e as Map<String, dynamic>))
        ?.toList(),
  );
}

Map<String, dynamic> _$EncodableTreeToJson(EncodableTree instance) => <String, dynamic>{
      'version': instance.version,
      'encodableStates': instance.encodableStates,
    };
