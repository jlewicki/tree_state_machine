// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tree_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializer<ReadOnlyData2> _$readOnlyData2Serializer =
    new _$ReadOnlyData2Serializer();

class _$ReadOnlyData2Serializer implements StructuredSerializer<ReadOnlyData2> {
  @override
  final Iterable<Type> types = const [ReadOnlyData2, _$ReadOnlyData2];
  @override
  final String wireName = 'ReadOnlyData2';

  @override
  Iterable<Object> serialize(Serializers serializers, ReadOnlyData2 object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object>[
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'counter',
      serializers.serialize(object.counter, specifiedType: const FullType(int)),
    ];

    return result;
  }

  @override
  ReadOnlyData2 deserialize(
      Serializers serializers, Iterable<Object> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new ReadOnlyData2Builder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final dynamic value = iterator.current;
      switch (key) {
        case 'name':
          result.name = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
        case 'counter':
          result.counter = serializers.deserialize(value,
              specifiedType: const FullType(int)) as int;
          break;
      }
    }

    return result.build();
  }
}

class _$ReadOnlyData2 extends ReadOnlyData2 {
  @override
  final String name;
  @override
  final int counter;

  factory _$ReadOnlyData2([void Function(ReadOnlyData2Builder) updates]) =>
      (new ReadOnlyData2Builder()..update(updates)).build();

  _$ReadOnlyData2._({this.name, this.counter}) : super._() {
    if (name == null) {
      throw new BuiltValueNullFieldError('ReadOnlyData2', 'name');
    }
    if (counter == null) {
      throw new BuiltValueNullFieldError('ReadOnlyData2', 'counter');
    }
  }

  @override
  ReadOnlyData2 rebuild(void Function(ReadOnlyData2Builder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ReadOnlyData2Builder toBuilder() => new ReadOnlyData2Builder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ReadOnlyData2 &&
        name == other.name &&
        counter == other.counter;
  }

  @override
  int get hashCode {
    return $jf($jc($jc(0, name.hashCode), counter.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('ReadOnlyData2')
          ..add('name', name)
          ..add('counter', counter))
        .toString();
  }
}

class ReadOnlyData2Builder
    implements Builder<ReadOnlyData2, ReadOnlyData2Builder> {
  _$ReadOnlyData2 _$v;

  String _name;
  String get name => _$this._name;
  set name(String name) => _$this._name = name;

  int _counter;
  int get counter => _$this._counter;
  set counter(int counter) => _$this._counter = counter;

  ReadOnlyData2Builder();

  ReadOnlyData2Builder get _$this {
    if (_$v != null) {
      _name = _$v.name;
      _counter = _$v.counter;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ReadOnlyData2 other) {
    if (other == null) {
      throw new ArgumentError.notNull('other');
    }
    _$v = other as _$ReadOnlyData2;
  }

  @override
  void update(void Function(ReadOnlyData2Builder) updates) {
    if (updates != null) updates(this);
  }

  @override
  _$ReadOnlyData2 build() {
    final _$result = _$v ?? new _$ReadOnlyData2._(name: name, counter: counter);
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new

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
    json['counter'] as int,
  );
}

Map<String, dynamic> _$ReadOnlyDataToJson(ReadOnlyData instance) =>
    <String, dynamic>{
      'name': instance.name,
      'counter': instance.counter,
    };
