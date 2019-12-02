import 'package:json_annotation/json_annotation.dart';

import 'tree_state_machine_2.dart';

part 'data_tree.g.dart';

@JsonSerializable()
class Item extends StateData {
  int count;
  int itemNumber;
  bool isRushed;

  Item();

  factory Item.fromJson(Map<String, dynamic> json) => _$ItemFromJson(json);

  Map<String, dynamic> toJson() => _$ItemToJson(this);
}
