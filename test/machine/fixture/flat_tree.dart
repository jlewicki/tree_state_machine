// ignore_for_file: constant_identifier_names

import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';

const r_1_key = StateKey('leaf1');
const r_2_key = StateKey('leaf2');

StateTree treeBuilder({
  MessageHandler? state1Handler,
  MessageHandler? state2Handler,
}) {
  return StateTree(
    InitialChild(r_1_key),
    childStates: [
      State(
        r_1_key,
        onMessage: state1Handler ?? emptyMessageHandler,
      ),
      State(
        r_2_key,
        onMessage: state2Handler ?? emptyMessageHandler,
      ),
    ],
  );
}
