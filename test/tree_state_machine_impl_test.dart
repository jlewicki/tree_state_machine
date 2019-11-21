import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

final rootState = _State();
final rootKey = StateKey.named('root');
final interior1 = _State();
final interior1Key = StateKey.named('interior1');
final child1 = _State();
final child1Key = StateKey.named('child1');
final child2 = _State();
final child2Key = StateKey.named('child2');

void main() {
  group('_Machine', () {
    final simpleTree = BuildRoot.keyed(
      key: rootKey,
      state: (key) => rootState,
      initialChild: (_) => interior1Key,
      children: [
        BuildInterior.keyed(
          key: interior1Key,
          state: (key) => interior1,
          initialChild: (_) => child1Key,
          children: [
            BuildLeaf.keyed(child1Key, (key) => child1),
            BuildLeaf.keyed(child2Key, (key) => child2),
          ],
        )
      ],
    );

    group('Initial Children', () {
      final buildCtx = BuildContext();
      final rootNode = simpleTree(buildCtx);
      final machine = Machine(rootNode, buildCtx.nodes);
      test('works', () async {
        final transCtx = await machine.enterInitialState(rootNode);
      });
    });
  });
}

class _State extends TreeState {
  TransitionHandler entryHandler;
  TransitionHandler exitHandler;
  MessageHandler messageHandler;

  _State({entryHandler, exitHandler, messageHandler}) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
    exitHandler = exitHandler ?? emptyTransitionHandler;
    messageHandler = messageHandler ?? emptyMessageHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext ctx) => entryHandler(ctx);
  @override
  FutureOr<MessageResult> onMessage(MessageContext ctx) => messageHandler(ctx);
  @override
  FutureOr<void> onExit(TransitionContext ctx) => exitHandler(ctx);
}

final TransitionHandler emptyTransitionHandler = (_) => {};
final MessageHandler emptyMessageHandler = (ctx) => ctx.unhandled();
