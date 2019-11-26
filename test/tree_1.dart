import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r_key = StateKey.named('r');
final r_a_key = StateKey.named('r_a');
final r_a_a_key = StateKey.named('r_a_a');
final r_a_1_key = StateKey.named('r_a_1');
final r_a_a_1_key = StateKey.named('r_a_a_1');
final r_a_a_2_key = StateKey.named('r_a_a_2');
final r_b_key = StateKey.named('r_a_b');
final r_b_1_key = StateKey.named('r_b_1');
final r_X_key = StateKey.named('r_X');

BuildRoot treeBuilder({
  MessageHandler r_handler,
  MessageHandler r_a_handler,
  MessageHandler r_a_a_handler,
  MessageHandler r_a_a_1_handler,
  MessageHandler r_a_a_2_handler,
  MessageHandler r_a_1_handler,
  MessageHandler r_b_handler,
  MessageHandler r_b_1_handler,
  TransitionHandler r_X_onEnter,
}) {
  return BuildRoot.keyed(
    key: r_key,
    state: (key) => DelegateState(messageHandler: r_handler),
    initialChild: (_) => r_a_key,
    terminalStates: [
      BuildTerminal.keyed(r_X_key, (key) => DelegateTerminalState(entryHandler: r_X_onEnter)),
    ],
    children: [
      BuildInterior.keyed(
        key: r_a_key,
        state: (key) => DelegateState(messageHandler: r_a_handler),
        initialChild: (_) => r_a_a_key,
        children: [
          BuildInterior.keyed(
            key: r_a_a_key,
            state: (key) => DelegateState(messageHandler: r_a_a_handler),
            initialChild: (_) => r_a_a_2_key,
            children: [
              BuildLeaf.keyed(r_a_a_1_key, (key) => DelegateState(messageHandler: r_a_a_1_handler)),
              BuildLeaf.keyed(r_a_a_2_key, (key) => DelegateState(messageHandler: r_a_a_2_handler)),
            ],
          ),
          BuildLeaf.keyed(r_a_1_key, (key) => DelegateState(messageHandler: r_a_1_handler)),
        ],
      ),
      BuildInterior.keyed(
        key: r_b_key,
        state: (key) => DelegateState(messageHandler: r_b_handler),
        initialChild: (_) => r_b_1_key,
        children: [
          BuildLeaf.keyed(r_b_1_key, (key) => DelegateState(messageHandler: r_b_1_handler)),
        ],
      ),
    ],
  );
}
