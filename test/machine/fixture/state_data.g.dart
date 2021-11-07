// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'state_data.dart';

// **************************************************************************
// BuiltValueGenerator
// **************************************************************************

Serializers _$serializers =
    (new Serializers().toBuilder()..add(ImmutableData.serializer)).build();
Serializer<ImmutableData> _$immutableDataSerializer =
    new _$ImmutableDataSerializer();

class _$ImmutableDataSerializer implements StructuredSerializer<ImmutableData> {
  @override
  final Iterable<Type> types = const [ImmutableData, _$ImmutableData];
  @override
  final String wireName = 'ImmutableData';

  @override
  Iterable<Object?> serialize(Serializers serializers, ImmutableData object,
      {FullType specifiedType = FullType.unspecified}) {
    final result = <Object?>[
      'name',
      serializers.serialize(object.name, specifiedType: const FullType(String)),
      'price',
      serializers.serialize(object.price, specifiedType: const FullType(int)),
    ];

    return result;
  }

  @override
  ImmutableData deserialize(
      Serializers serializers, Iterable<Object?> serialized,
      {FullType specifiedType = FullType.unspecified}) {
    final result = new ImmutableDataBuilder();

    final iterator = serialized.iterator;
    while (iterator.moveNext()) {
      final key = iterator.current as String;
      iterator.moveNext();
      final Object? value = iterator.current;
      switch (key) {
        case 'name':
          result.name = serializers.deserialize(value,
              specifiedType: const FullType(String)) as String;
          break;
        case 'price':
          result.price = serializers.deserialize(value,
              specifiedType: const FullType(int)) as int;
          break;
      }
    }

    return result.build();
  }
}

class _$ImmutableData extends ImmutableData {
  @override
  final String name;
  @override
  final int price;

  factory _$ImmutableData([void Function(ImmutableDataBuilder)? updates]) =>
      (new ImmutableDataBuilder()..update(updates)).build();

  _$ImmutableData._({required this.name, required this.price}) : super._() {
    BuiltValueNullFieldError.checkNotNull(name, 'ImmutableData', 'name');
    BuiltValueNullFieldError.checkNotNull(price, 'ImmutableData', 'price');
  }

  @override
  ImmutableData rebuild(void Function(ImmutableDataBuilder) updates) =>
      (toBuilder()..update(updates)).build();

  @override
  ImmutableDataBuilder toBuilder() => new ImmutableDataBuilder()..replace(this);

  @override
  bool operator ==(Object other) {
    if (identical(other, this)) return true;
    return other is ImmutableData && name == other.name && price == other.price;
  }

  @override
  int get hashCode {
    return $jf($jc($jc(0, name.hashCode), price.hashCode));
  }

  @override
  String toString() {
    return (newBuiltValueToStringHelper('ImmutableData')
          ..add('name', name)
          ..add('price', price))
        .toString();
  }
}

class ImmutableDataBuilder
    implements Builder<ImmutableData, ImmutableDataBuilder> {
  _$ImmutableData? _$v;

  String? _name;
  String? get name => _$this._name;
  set name(String? name) => _$this._name = name;

  int? _price;
  int? get price => _$this._price;
  set price(int? price) => _$this._price = price;

  ImmutableDataBuilder();

  ImmutableDataBuilder get _$this {
    final $v = _$v;
    if ($v != null) {
      _name = $v.name;
      _price = $v.price;
      _$v = null;
    }
    return this;
  }

  @override
  void replace(ImmutableData other) {
    ArgumentError.checkNotNull(other, 'other');
    _$v = other as _$ImmutableData;
  }

  @override
  void update(void Function(ImmutableDataBuilder)? updates) {
    if (updates != null) updates(this);
  }

  @override
  _$ImmutableData build() {
    final _$result = _$v ??
        new _$ImmutableData._(
            name: BuiltValueNullFieldError.checkNotNull(
                name, 'ImmutableData', 'name'),
            price: BuiltValueNullFieldError.checkNotNull(
                price, 'ImmutableData', 'price'));
    replace(_$result);
    return _$result;
  }
}

// ignore_for_file: always_put_control_body_on_new_line,always_specify_types,annotate_overrides,avoid_annotating_with_dynamic,avoid_as,avoid_catches_without_on_clauses,avoid_returning_this,deprecated_member_use_from_same_package,lines_longer_than_80_chars,omit_local_variable_types,prefer_expression_function_bodies,sort_constructors_first,test_types_in_equals,unnecessary_const,unnecessary_new

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

SimpleDataD _$SimpleDataDFromJson(Map<String, dynamic> json) => SimpleDataD()
  ..playerName = json['playerName'] as String?
  ..hiScores = (json['hiScores'] as List<dynamic>)
      .map((e) => HiScore.fromJson(e as Map<String, dynamic>))
      .toList();

Map<String, dynamic> _$SimpleDataDToJson(SimpleDataD instance) =>
    <String, dynamic>{
      'playerName': instance.playerName,
      'hiScores': instance.hiScores,
    };

SpecialDataD _$SpecialDataDFromJson(Map<String, dynamic> json) => SpecialDataD()
  ..playerName = json['playerName'] as String?
  ..hiScores = (json['hiScores'] as List<dynamic>)
      .map((e) => HiScore.fromJson(e as Map<String, dynamic>))
      .toList()
  ..startYear = json['startYear'] as int?;

Map<String, dynamic> _$SpecialDataDToJson(SpecialDataD instance) =>
    <String, dynamic>{
      'playerName': instance.playerName,
      'hiScores': instance.hiScores,
      'startYear': instance.startYear,
    };

HiScore _$HiScoreFromJson(Map<String, dynamic> json) => HiScore(
      json['game'] as String,
      json['score'] as int,
    );

Map<String, dynamic> _$HiScoreToJson(HiScore instance) => <String, dynamic>{
      'game': instance.game,
      'score': instance.score,
    };

LeafDataBase _$LeafDataBaseFromJson(Map<String, dynamic> json) =>
    LeafDataBase()..name = json['name'] as String?;

Map<String, dynamic> _$LeafDataBaseToJson(LeafDataBase instance) =>
    <String, dynamic>{
      'name': instance.name,
    };

LeafData1 _$LeafData1FromJson(Map<String, dynamic> json) =>
    LeafData1()..counter = json['counter'] as int?;

Map<String, dynamic> _$LeafData1ToJson(LeafData1 instance) => <String, dynamic>{
      'counter': instance.counter,
    };

LeafData2 _$LeafData2FromJson(Map<String, dynamic> json) =>
    LeafData2()..label = json['label'] as String?;

Map<String, dynamic> _$LeafData2ToJson(LeafData2 instance) => <String, dynamic>{
      'label': instance.label,
    };

ReadOnlyData _$ReadOnlyDataFromJson(Map<String, dynamic> json) => ReadOnlyData(
      json['name'] as String,
      json['counter'] as int,
    );

Map<String, dynamic> _$ReadOnlyDataToJson(ReadOnlyData instance) =>
    <String, dynamic>{
      'name': instance.name,
      'counter': instance.counter,
    };
