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
  TransitionHandler createEntryHandler(StateKey key),
  TransitionHandler createExitHandler(StateKey key),
  MessageHandler createMessageHandler(StateKey key),
  Map<StateKey, TransitionHandler> entryHandlers,
  Map<StateKey, MessageHandler> messageHandlers,
  Map<StateKey, TransitionHandler> exitHandlers,
}) {
  final _createEntryHandler = createEntryHandler ?? (_) => emptyTransitionHandler;
  final _createExitHandler = createExitHandler ?? (_) => emptyTransitionHandler;
  final _createMessageHandler = createMessageHandler ?? (_) => emptyMessageHandler;
  final _entryHandlers = entryHandlers ?? {};
  final _messageHandlers = messageHandlers ?? {};
  final _exitHandlers = exitHandlers ?? {};

  DelegateState createState(StateKey key) => DelegateState(
      entryHandler: _entryHandlers[key] ?? _createEntryHandler(key),
      messageHandler: _messageHandlers[key] ?? _createMessageHandler(key),
      exitHandler: _exitHandlers[key] ?? _createExitHandler(key));

  return BuildRoot.keyed(
    key: r_key,
    state: createState,
    initialChild: (_) => r_a_key,
    terminalStates: [
      BuildTerminal.keyed(r_X_key, (key) => DelegateTerminalState(_exitHandlers[key])),
    ],
    children: [
      BuildInterior.keyed(
        key: r_a_key,
        state: createState,
        initialChild: (_) => r_a_a_key,
        children: [
          BuildInterior.keyed(
            key: r_a_a_key,
            state: createState,
            initialChild: (_) => r_a_a_2_key,
            children: [
              BuildLeaf.keyed(r_a_a_1_key, createState),
              BuildLeaf.keyed(r_a_a_2_key, createState),
            ],
          ),
          BuildLeaf.keyed(r_a_1_key, createState),
        ],
      ),
      BuildInterior.keyed(
        key: r_b_key,
        state: createState,
        initialChild: (_) => r_b_1_key,
        children: [
          BuildLeaf.keyed(r_b_1_key, createState),
        ],
      ),
    ],
  );
}
