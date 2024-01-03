// ignore_for_file: constant_identifier_names

import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';

const r_key = StateKey('r');
const r_a_key = StateKey('r_a');
const r_a_a_key = StateKey('r_a_a');
const r_a_a_1_key = StateKey('r_a_a_1');
const r_a_a_2_key = StateKey('r_a_a_2');
const r_b_key = StateKey('r_b');
const r_b_1_key = StateKey('r_b_1');
const r_b_2_key = StateKey('r_b_2');
const r_X_key = StateKey('r_X');

final initialStateKey = r_a_a_2_key;

StateTree treeBuilder({
  String? name,
  TransitionHandler Function(StateKey key)? createEntryHandler,
  TransitionHandler Function(StateKey key)? createExitHandler,
  MessageHandler Function(StateKey key)? createMessageHandler,
  void Function(TransitionContext) Function(StateKey key)?
      createInitialChildCallback,
  Map<StateKey, TransitionHandler>? entryHandlers,
  Map<StateKey, MessageHandler>? messageHandlers,
  Map<StateKey, TransitionHandler>? exitHandlers,
  Map<StateKey, void Function(TransitionContext)>? initialChildCallbacks,
}) {
  final createEntryHandler_ =
      createEntryHandler ?? (_) => emptyTransitionHandler;
  final createExitHandler_ = createExitHandler ?? (_) => emptyTransitionHandler;
  final createMessageHandler_ =
      createMessageHandler ?? (_) => emptyMessageHandler;
  final entryHandlers_ = entryHandlers ?? {};
  final messageHandlers_ = messageHandlers ?? {};
  final exitHandlers_ = exitHandlers ?? {};
  final initialChildCallbacks_ = initialChildCallbacks ?? {};

  MessageHandler messageHandler_(StateKey key) {
    return messageHandlers_[key] ?? createMessageHandler_(key);
  }

  TransitionHandler entryHandler_(StateKey key) {
    return entryHandlers_[key] ?? createEntryHandler_(key);
  }

  TransitionHandler exitHandler_(StateKey key) {
    return exitHandlers_[key] ?? createExitHandler_(key);
  }

  State buildState(
    StateKey key, {
    InitialChild? initialChild,
    List<StateConfig>? childStates,
  }) {
    return initialChild != null
        ? State.composite(key, initialChild,
            onEnter: entryHandler_(key),
            onMessage: messageHandler_(key),
            onExit: exitHandler_(key),
            childStates: childStates!)
        : State(key,
            onEnter: entryHandler_(key),
            onMessage: messageHandler_(key),
            onExit: exitHandler_(key));
  }

  void Function(TransitionContext) initialChildCallback(StateKey key) =>
      initialChildCallbacks_[key] ??
      (createInitialChildCallback != null
          ? createInitialChildCallback(key)
          : (_) {});

  return StateTree.root(r_key, InitialChild.run(
    (ctx) {
      initialChildCallback(r_key)(ctx);
      return r_a_key;
    },
  ),
      onEnter: entryHandler_(r_key),
      onMessage: messageHandler_(r_key),
      onExit: exitHandler_(r_key),
      childStates: [
        buildState(
          r_a_key,
          initialChild: InitialChild.run(
            (ctx) {
              initialChildCallback(r_a_key)(ctx);
              return r_a_a_key;
            },
          ),
          childStates: [
            buildState(
              r_a_a_key,
              initialChild: InitialChild.run((ctx) {
                initialChildCallback(r_a_a_key)(ctx);
                return r_a_a_2_key;
              }),
              childStates: [
                buildState(r_a_a_1_key),
                buildState(r_a_a_2_key),
              ],
            ),
          ],
        ),
        buildState(
          r_b_key,
          initialChild: InitialChild.run(
            (ctx) {
              initialChildCallback(r_b_key)(ctx);
              return r_b_1_key;
            },
          ),
          childStates: [
            buildState(r_b_1_key),
            buildState(r_b_2_key),
          ],
        ),
      ],
      finalStates: [
        FinalState(
          r_X_key,
          onEnter: entryHandler_(r_X_key),
        )
      ]);
}
