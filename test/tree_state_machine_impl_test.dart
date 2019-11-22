import 'dart:async';

import 'package:test/test.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';
import 'package:tree_state_machine/src/tree_state_machine_impl.dart';

void main() {
  group('Machine', () {
    final r = _State();
    final r_key = StateKey.named('r');
    final r_a = _State();
    final r_a_key = StateKey.named('r_a');
    final r_a_a = _State();
    final r_a_a_key = StateKey.named('r_a_a');
    final r_a_b = _State();
    final r_a_b_key = StateKey.named('r_a_b');
    final r_a_1 = _State();
    final r_a_1_key = StateKey.named('r_a_1');
    final r_a_a_1 = _State();
    final r_a_a_1_key = StateKey.named('r_a_a_1');
    final r_a_a_2 = _State();
    final r_a_a_2_key = StateKey.named('r_a_a_2');
    final r_b_1 = _State();
    final r_b_1_key = StateKey.named('r_b_1');

    final buildATree = BuildRoot.keyed(
      key: r_key,
      state: (key) => r,
      initialChild: (_) => r_a_key,
      children: [
        BuildInterior.keyed(
          key: r_a_key,
          state: (key) => r_a,
          initialChild: (_) => r_a_a_key,
          children: [
            BuildInterior.keyed(
              key: r_a_a_key,
              state: (key) => r_a_a,
              initialChild: (_) => r_a_a_2_key,
              children: [
                BuildLeaf.keyed(r_a_a_1_key, (key) => r_a_a_1),
                BuildLeaf.keyed(r_a_a_2_key, (key) => r_a_a_2),
              ],
            ),
            BuildLeaf.keyed(r_a_1_key, (key) => r_a_1),
          ],
        ),
        BuildInterior.keyed(
          key: r_a_b_key,
          state: (key) => r_a_b,
          initialChild: (_) => r_b_1_key,
          children: [
            BuildLeaf.keyed(r_b_1_key, (key) => r_b_1),
          ],
        ),
      ],
    );

    group('enterInitialState', () {
      final buildCtx = BuildContext();
      final rootNode = buildATree(buildCtx);
      final machine = Machine(rootNode, buildCtx.nodes);

      test('should follow initial children when starting at root', () async {
        final MachineTransitionContext transCtx = await machine.enterInitialState(rootNode.key);

        expect(transCtx.from, equals(r_key));

        expect(transCtx.to, equals(r_a_a_2_key));
        expect(
          transCtx.path(),
          orderedEquals([r_key, r_a_key, r_a_a_key, r_a_a_2_key]),
        );
      });

      test('should descend to initial state when initial state is a leaf', () async {
        final leafNode = buildCtx.nodes[r_b_1_key];
        final MachineTransitionContext transCtx = await machine.enterInitialState(leafNode.key);

        expect(transCtx.from, equals(r_key));
        expect(transCtx.to, equals(leafNode.key));
        expect(
          transCtx.path().map((ref) => ref),
          orderedEquals([r_key, r_a_b_key, r_b_1_key]),
        );
      });

      test(
          'should descend to initial state, then follow initial children, when initial state an interior',
          () async {
        final interiorNode = buildCtx.nodes[r_a_a_key];
        final MachineTransitionContext transCtx = await machine.enterInitialState(interiorNode.key);

        expect(transCtx.from, equals(r_key));
        expect(transCtx.to, equals(r_a_a_2_key));
        expect(
          transCtx.path(),
          orderedEquals([r_key, r_a_key, r_a_a_key, r_a_a_2_key]),
        );
      });

      test('should throw if initialChild returns null', () {
        final buildTree =
            BuildRoot.keyed(key: r_key, state: (key) => r, initialChild: (_) => null, children: [
          BuildLeaf.keyed(r_a_1_key, (key) => r_a_1),
        ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
      });

      test('should throw if initialChild references a state that is not a child', () {
        final buildTree = BuildRoot.keyed(
            key: r_key,
            state: (key) => r,
            initialChild: (_) => r_a_a_1_key,
            children: [
              BuildLeaf.keyed(r_a_1_key, (key) => r_a_1),
            ]);
        final buildCtx = BuildContext();
        final rootNode = buildTree(buildCtx);
        final machine = Machine(rootNode, buildCtx.nodes);

        expect(() => machine.enterInitialState(rootNode.key), throwsStateError);
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
