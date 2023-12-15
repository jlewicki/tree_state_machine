import 'package:collection/collection.dart';
import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'fixture/fixture_util.dart';
import 'fixture/data_tree.dart';

void main() {
  group('MachineMessageContext', () {
    test(
        'should run message filters with handling state the same as filtered state',
        () async {
      var handlingStates = <StateKey>[];
      final buildTree = treeBuilder(filters: {
        r_a_a_2_key: [
          TreeStateFilter(onMessage: (msgCtx, next) {
            handlingStates.add(msgCtx.handlingState);
            var result = next();
            handlingStates.add(msgCtx.handlingState);
            return result;
          })
        ],
        r_a_a_key: [
          TreeStateFilter(onMessage: (msgCtx, next) {
            handlingStates.add(msgCtx.handlingState);
            var result = next();
            handlingStates.add(msgCtx.handlingState);
            return result;
          })
        ],
        r_a_key: [
          TreeStateFilter(onMessage: (msgCtx, next) {
            handlingStates.add(msgCtx.handlingState);
            var result = next();
            handlingStates.add(msgCtx.handlingState);
            return result;
          })
        ],
      });

      final machine = createMachine(buildTree);
      await machine.enterInitialState();
      await machine.processMessage(Object());

      expect(
          ListEquality<StateKey>().equals(
            [r_a_a_2_key, r_a_a_2_key, r_a_a_key, r_a_a_key, r_a_key, r_a_key],
            handlingStates,
          ),
          isTrue);
    });

    test('should run message filters in order', () async {
      var filtersExecutedBefore = <int>[];
      var filtersExecutedAfter = <int>[];
      var wasTreeStateHandlerRun = false;
      final buildTree = treeBuilder(
        filters: {
          r_a_a_2_key: [
            TreeStateFilter(onMessage: (msgCtx, next) {
              filtersExecutedBefore.add(1);
              var result = next();
              filtersExecutedAfter.add(1);
              return result;
            }),
            TreeStateFilter(onMessage: (msgCtx, next) {
              filtersExecutedBefore.add(2);
              var result = next();
              filtersExecutedAfter.add(2);
              return result;
            }),
            TreeStateFilter(onMessage: (msgCtx, next) {
              filtersExecutedBefore.add(3);
              var result = next();
              filtersExecutedAfter.add(3);
              return result;
            })
          ],
        },
        messageHandlers: {
          r_a_a_2_key: (ctx) {
            wasTreeStateHandlerRun = true;
            return ctx.stay();
          }
        },
      );

      final machine = createMachine(buildTree);
      await machine.enterInitialState();
      var result = await machine.processMessage(Object());

      expect(
          ListEquality<int>().equals([1, 2, 3], filtersExecutedBefore), isTrue);
      expect(
          ListEquality<int>().equals([3, 2, 1], filtersExecutedAfter), isTrue);
      expect(result, isA<HandledMessage>());
      expect(wasTreeStateHandlerRun, isTrue);
    });
  });
}
