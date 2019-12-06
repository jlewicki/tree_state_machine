import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r_key = StateKey.named('r');
final r_a_key = StateKey.named('r_a');
final r_a_a_key = StateKey.named('r_a_a');
final r_a_1_key = StateKey.named('r_a_1');
final r_a_a_1_key = StateKey.named('r_a_a_1');
final r_a_a_2_key = StateKey.named('r_a_a_2');
final r_b_key = StateKey.named('r_b');
final r_b_1_key = StateKey.named('r_b_1');
final r_b_2_key = StateKey.named('r_b_2');
final r_X_key = StateKey.named('r_X');

final initialStateKey = r_a_a_2_key;

abstract class ReadOnlyData {
  int get counter;
}

class ReadOnlyDelegateState extends DelegateState implements ReadOnlyData {
  int counter;
  ReadOnlyDelegateState(
    this.counter, {
    TransitionHandler entryHandler,
    TransitionHandler exitHandler,
    MessageHandler messageHandler,
  }) : super(entryHandler: entryHandler, exitHandler: exitHandler, messageHandler: messageHandler);
}

RootNodeBuilder treeBuilder({
  TransitionHandler createEntryHandler(StateKey key),
  TransitionHandler createExitHandler(StateKey key),
  MessageHandler createMessageHandler(StateKey key),
  void Function(TransitionContext) createInitialChildCallback(StateKey key),
  Map<StateKey, TransitionHandler> entryHandlers,
  Map<StateKey, MessageHandler> messageHandlers,
  Map<StateKey, TransitionHandler> exitHandlers,
  Map<StateKey, void Function(TransitionContext)> initialChildCallbacks,
}) {
  final _createEntryHandler = createEntryHandler ?? (_) => emptyTransitionHandler;
  final _createExitHandler = createExitHandler ?? (_) => emptyTransitionHandler;
  final _createMessageHandler = createMessageHandler ?? (_) => emptyMessageHandler;
  //final _createInitialChildCallback = createInitialChildCallback ?? (_) {};
  final _entryHandlers = entryHandlers ?? {};
  final _messageHandlers = messageHandlers ?? {};
  final _exitHandlers = exitHandlers ?? {};
  final _initialChildCallbacks = initialChildCallbacks ?? {};

  DelegateState createState(StateKey key) => DelegateState(
      entryHandler: _entryHandlers[key] ?? _createEntryHandler(key),
      messageHandler: _messageHandlers[key] ?? _createMessageHandler(key),
      exitHandler: _exitHandlers[key] ?? _createExitHandler(key));

  DelegateState createReadOnlyState(StateKey key, int counterVal) =>
      ReadOnlyDelegateState(counterVal,
          entryHandler: _entryHandlers[key] ?? _createEntryHandler(key),
          messageHandler: _messageHandlers[key] ?? _createMessageHandler(key),
          exitHandler: _exitHandlers[key] ?? _createExitHandler(key));

  void Function(TransitionContext) _initialChildCallback(StateKey key) =>
      _initialChildCallbacks[key] ??
      (createInitialChildCallback != null ? createInitialChildCallback(key) : (_) {});

  return rootBuilder(
    key: r_key,
    createState: createState,
    initialChild: (ctx) {
      _initialChildCallback(r_key)(ctx);
      return r_a_key;
    },
    finalStates: [
      finalBuilder(key: r_X_key, createState: (key) => DelegateFinalState(_exitHandlers[key])),
    ],
    children: [
      interiorBuilder(
        key: r_a_key,
        state: createState,
        initialChild: (ctx) {
          _initialChildCallback(r_a_key)(ctx);
          return r_a_a_key;
        },
        children: [
          interiorBuilder(
            key: r_a_a_key,
            state: createState,
            initialChild: (ctx) {
              _initialChildCallback(r_a_a_key)(ctx);
              return r_a_a_2_key;
            },
            children: [
              leafBuilder(key: r_a_a_1_key, createState: createState),
              leafBuilder(key: r_a_a_2_key, createState: createState),
            ],
          ),
          leafBuilder(key: r_a_1_key, createState: createState),
        ],
      ),
      interiorBuilder(
        key: r_b_key,
        state: createState,
        initialChild: (ctx) {
          _initialChildCallback(r_b_key)(ctx);
          return r_b_1_key;
        },
        children: [
          leafBuilder(key: r_b_1_key, createState: createState),
          leafBuilder(key: r_b_2_key, createState: (k) => createReadOnlyState(k, 10)),
        ],
      ),
    ],
  );
}
