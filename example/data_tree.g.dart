// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'data_tree.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Item _$ItemFromJson(Map<String, dynamic> json) {
  return Item()
    ..count = json['count'] as int
    ..itemNumber = json['itemNumber'] as int
    ..isRushed = json['isRushed'] as bool;
}

Map<String, dynamic> _$ItemToJson(Item instance) => <String, dynamic>{
      'count': instance.count,
      'itemNumber': instance.itemNumber,
      'isRushed': instance.isRushed,
    };
