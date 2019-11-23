import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r_1 = DelegateState();
final r_1_key = StateKey.named('leaf1');
final r_2 = DelegateState();
final r_2_key = StateKey.named('leaf2');

final leaves = [
  BuildLeaf.keyed(r_1_key, (key) => r_1),
  BuildLeaf.keyed(r_2_key, (key) => r_2),
];
