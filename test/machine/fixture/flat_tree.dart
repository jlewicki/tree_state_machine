// ignore_for_file: constant_identifier_names

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/tree_builders.dart';

const r_1_key = StateKey('leaf1');
const r_2_key = StateKey('leaf2');

DeclarativeStateTreeBuilder treeBuilder({
  MessageHandler? state1Handler,
  MessageHandler? state2Handler,
}) {
  var b = DeclarativeStateTreeBuilder(initialChild: r_1_key);
  b.state(r_1_key, (b) {
    if (state1Handler != null) b.handleOnMessage(state1Handler);
  });
  b.state(r_2_key, (b) {
    if (state2Handler != null) b.handleOnMessage(state2Handler);
  });
  return b;
}
