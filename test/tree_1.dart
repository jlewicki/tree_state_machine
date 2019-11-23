import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r = DelegateState();
final r_key = StateKey.named('r');
final r_a = DelegateState();
final r_a_key = StateKey.named('r_a');
final r_a_a = DelegateState();
final r_a_a_key = StateKey.named('r_a_a');
final r_a_b = DelegateState();
final r_a_b_key = StateKey.named('r_a_b');
final r_a_1 = DelegateState();
final r_a_1_key = StateKey.named('r_a_1');
final r_a_a_1 = DelegateState();
final r_a_a_1_key = StateKey.named('r_a_a_1');
final r_a_a_2 = DelegateState();
final r_a_a_2_key = StateKey.named('r_a_a_2');
final r_b_1 = DelegateState();
final r_b_1_key = StateKey.named('r_b_1');

final buildTree = BuildRoot.keyed(
  key: r_key,
  state: (key) => r,
  initialChild: (_) => r_a_key,
  children: [
    BuildInterior.keyed(
      key: r_a_key,
      state: (key) => r_a,
      initialChild: (_) => r_a_a_key,
      children: [
        BuildInterior.keyed(
          key: r_a_a_key,
          state: (key) => r_a_a,
          initialChild: (_) => r_a_a_2_key,
          children: [
            BuildLeaf.keyed(r_a_a_1_key, (key) => r_a_a_1),
            BuildLeaf.keyed(r_a_a_2_key, (key) => r_a_a_2),
          ],
        ),
        BuildLeaf.keyed(r_a_1_key, (key) => r_a_1),
      ],
    ),
    BuildInterior.keyed(
      key: r_a_b_key,
      state: (key) => r_a_b,
      initialChild: (_) => r_b_1_key,
      children: [
        BuildLeaf.keyed(r_b_1_key, (key) => r_b_1),
      ],
    ),
  ],
);
