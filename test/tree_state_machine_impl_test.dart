import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

void main() {
  final rootState = _State();
  final rootKey = StateKey.named('root');
  final interior1 = _State();
  final interior1Key = StateKey.named('interior1');
  final child1 = _State();
  final child1Key = StateKey.named('child1');
  final child2 = _State();
  final child2Key = StateKey.named('child2');

  group('Machine', () {
    final simpleTree = BuildRoot.keyed(
      key: rootKey,
      state: (key) => rootState,
      initialChild: (_) => interior1Key,
      children: [
        BuildInterior.keyed(
          key: interior1Key,
          state: (key) => interior1,
          initialChild: (_) => child2Key,
          children: [
            BuildLeaf.keyed(child1Key, (key) => child1),
            BuildLeaf.keyed(child2Key, (key) => child2),
          ],
        )
      ],
    );

    group('enterInitialState', () {
      final buildCtx = BuildContext();
      final rootNode = simpleTree(buildCtx);
      final machine = Machine(rootNode, buildCtx.nodes);

      test('should follow initial children when starting at root', () async {
        final MachineTransitionContext transCtx = await machine.enterInitialState(rootNode);

        expect(transCtx.fromState.key, equals(rootKey));
        expect(transCtx.toState.key, equals(child2Key));
        expect(
          transCtx.transitionPath().map((ref) => ref.key),
          orderedEquals([rootKey, interior1Key, child2Key]),
        );
      });

      test('should descend to initial state when initial state is a leaf', () async {
        final leafNode = buildCtx.nodes[child1Key];
        final MachineTransitionContext transCtx = await machine.enterInitialState(leafNode);

        expect(transCtx.fromState.key, equals(rootKey));
        expect(transCtx.toState.key, equals(leafNode.key));
        expect(
          transCtx.transitionPath().map((ref) => ref.key),
          orderedEquals([rootKey, interior1Key, child1Key]),
        );
      });

      test(
          'should descend to initial state, then follow initial children, when initial state an interior',
          () async {
        final interiorNode = buildCtx.nodes[interior1Key];
        final MachineTransitionContext transCtx = await machine.enterInitialState(interiorNode);

        expect(transCtx.fromState.key, equals(rootKey));
        expect(transCtx.toState.key, equals(child2Key));
        expect(
          transCtx.transitionPath().map((ref) => ref.key),
          orderedEquals([rootKey, interior1Key, child2Key]),
        );
      });

      test('should throw if initialChild returns null', () {
        final buildTree = BuildRoot.keyed(
            key: rootKey,
            state: (key) => rootState,
            initialChild: (_) => null,
            children: [
              BuildLeaf.keyed(child1Key, (key) => child1),
            ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode), throwsStateError);
      });

      test('should throw if initialChild references a state that is not a child', () {
        final buildTree = BuildRoot.keyed(
            key: rootKey,
            state: (key) => rootState,
            initialChild: (_) => child2Key,
            children: [
              BuildLeaf.keyed(child1Key, (key) => child1),
            ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode), throwsStateError);
      });
    });
  });
}

class _State extends TreeState {
  TransitionHandler entryHandler;
  TransitionHandler exitHandler;
  MessageHandler messageHandler;

  _State({this.entryHandler, this.exitHandler, this.messageHandler}) {
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
