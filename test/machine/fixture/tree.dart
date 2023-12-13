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
  String? name,
  TransitionHandler Function(StateKey key)? createEntryHandler,
  TransitionHandler Function(StateKey key)? createExitHandler,
  MessageHandler Function(StateKey key)? createMessageHandler,
  void Function(TransitionContext) Function(StateKey key)? createInitialChildCallback,
  Map<StateKey, TransitionHandler>? entryHandlers,
  Map<StateKey, MessageHandler>? messageHandlers,
  Map<StateKey, TransitionHandler>? exitHandlers,
  Map<StateKey, void Function(TransitionContext)>? initialChildCallbacks,
}) {
  final createEntryHandler_ = createEntryHandler ?? (_) => emptyTransitionHandler;
  final createExitHandler_ = createExitHandler ?? (_) => emptyTransitionHandler;
  final createMessageHandler_ = createMessageHandler ?? (_) => emptyMessageHandler;
  final entryHandlers_ = entryHandlers ?? {};
  final messageHandlers_ = messageHandlers ?? {};
  final exitHandlers_ = exitHandlers ?? {};
  final initialChildCallbacks_ = initialChildCallbacks ?? {};

  void Function(StateBuilder<void>) buildState(StateKey key) {
    return (b) {
      b.handleOnMessage(messageHandlers_[key] ?? createMessageHandler_(key));
      b.handleOnEnter(entryHandlers_[key] ?? createEntryHandler_(key));
      b.handleOnExit(exitHandlers_[key] ?? createExitHandler_(key));
    };
  }

  void Function(EnterStateBuilder<void>) buildFinalState(StateKey key) {
    return (b) {
      b.handleOnEnter(entryHandlers_[key] ?? createEntryHandler_(key));
    };
  }

  void Function(TransitionContext) initialChildCallback(StateKey key) =>
      initialChildCallbacks_[key] ??
      (createInitialChildCallback != null ? createInitialChildCallback(key) : (_) {});

  var b = StateTreeBuilder.withRoot(
    r_key,
    InitialChild.run(
      (ctx) {
        initialChildCallback(r_key)(ctx);
        return r_a_key;
      },
    ),
    buildState(r_key),
    label: name,
  );

  b.finalState(r_X_key, buildFinalState(r_X_key));

  b.state(
    r_a_key,
    buildState(r_a_key),
    parent: r_key,
    initialChild: InitialChild.run((ctx) {
      initialChildCallback(r_a_key)(ctx);
      return r_a_a_key;
    }),
  );

  b.state(
    r_a_a_key,
    buildState(r_a_a_key),
    parent: r_a_key,
    initialChild: InitialChild.run((ctx) {
      initialChildCallback(r_a_a_key)(ctx);
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
      initialChildCallback(r_b_key)(ctx);
      return r_b_1_key;
    }),
  );

  b.state(r_b_1_key, buildState(r_b_1_key), parent: r_b_key);
  b.state(r_b_2_key, buildState(r_b_2_key), parent: r_b_key);

  return b;
}
