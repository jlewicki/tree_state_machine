// ignore_for_file: constant_identifier_names

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/tree_builders.dart';

const r_key = StateKey('r');
const r_a_key = StateKey('r_a');
const r_a_a_key = StateKey('r_a_a');
const r_a_1_key = StateKey('r_a_1');
const r_a_a_1_key = StateKey('r_a_a_1');
const r_a_a_2_key = StateKey('r_a_a_2');
const r_b_key = StateKey('r_b');
const r_b_1_key = StateKey('r_b_1');
const r_b_2_key = StateKey('r_b_2');
const r_X_key = StateKey('r_X');

final initialStateKey = r_a_a_2_key;

StateTreeBuilder treeBuilder({
  TransitionHandler Function(StateKey key)? createEntryHandler,
  TransitionHandler Function(StateKey key)? createExitHandler,
  MessageHandler Function(StateKey key)? createMessageHandler,
  void Function(TransitionContext) Function(StateKey key)? createInitialChildCallback,
  Map<StateKey, TransitionHandler>? entryHandlers,
  Map<StateKey, MessageHandler>? messageHandlers,
  Map<StateKey, TransitionHandler>? exitHandlers,
  Map<StateKey, void Function(TransitionContext)>? initialChildCallbacks,
}) {
  final _createEntryHandler = createEntryHandler ?? (_) => emptyTransitionHandler;
  final _createExitHandler = createExitHandler ?? (_) => emptyTransitionHandler;
  final _createMessageHandler = createMessageHandler ?? (_) => emptyMessageHandler;
  final _entryHandlers = entryHandlers ?? {};
  final _messageHandlers = messageHandlers ?? {};
  final _exitHandlers = exitHandlers ?? {};
  final _initialChildCallbacks = initialChildCallbacks ?? {};

  void Function(StateBuilder) buildState(StateKey key) {
    return (b) {
      b.runOnMessage(_messageHandlers[key] ?? _createMessageHandler(key));
      b.runOnEnter(_entryHandlers[key] ?? _createEntryHandler(key));
      b.runOnExit(_exitHandlers[key] ?? _createExitHandler(key));
    };
  }

  void Function(FinalStateBuilder) buildFinalState(StateKey key) {
    return (b) {
      b.runOnEnter(_entryHandlers[key] ?? _createEntryHandler(key));
    };
  }

  void Function(TransitionContext) _initialChildCallback(StateKey key) =>
      _initialChildCallbacks[key] ??
      (createInitialChildCallback != null ? createInitialChildCallback(key) : (_) {});

  var b = StateTreeBuilder.withRoot(r_key, buildState(r_key), InitialChild.run(
    (ctx) {
      _initialChildCallback(r_key)(ctx);
      return r_a_key;
    },
  ));

  b.finalState(r_X_key, buildFinalState(r_X_key));

  b.state(
    r_a_key,
    buildState(r_a_key),
    parent: r_key,
    initialChild: InitialChild.run((ctx) {
      _initialChildCallback(r_a_key)(ctx);
      return r_a_a_key;
    }),
  );

  b.state(
    r_a_a_key,
    buildState(r_a_a_key),
    parent: r_a_key,
    initialChild: InitialChild.run((ctx) {
      _initialChildCallback(r_a_a_key)(ctx);
      return r_a_a_2_key;
    }),
  );

  b.state(r_a_a_1_key, buildState(r_a_a_1_key), parent: r_a_a_key);
  b.state(r_a_a_2_key, buildState(r_a_a_2_key), parent: r_a_a_key);

  b.state(
    r_b_key,
    buildState(r_b_key),
    parent: r_key,
    initialChild: InitialChild.run((ctx) {
      _initialChildCallback(r_b_key)(ctx);
      return r_b_1_key;
    }),
  );

  b.state(r_b_1_key, buildState(r_b_1_key), parent: r_b_key);
  b.state(r_b_2_key, buildState(r_b_2_key), parent: r_b_key);

  return b;
}
