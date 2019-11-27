import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r_key = StateKey.named('root');
final r_1_key = StateKey.named('leaf1');
final r_2_key = StateKey.named('leaf2');

final leaves = [
  BuildLeaf.keyed(r_1_key, (key) => DelegateState()),
  BuildLeaf.keyed(r_2_key, (key) => DelegateState()),
];

BuildRoot treeBuilder({
  MessageHandler rootHandler,
  MessageHandler state1Handler,
  MessageHandler state2Handler,
}) {
  return BuildRoot.keyed(
      key: r_key,
      state: (key) => DelegateState(messageHandler: rootHandler),
      initialChild: (_) => r_1_key,
      children: [
        BuildLeaf.keyed(r_1_key, (key) => DelegateState(messageHandler: state1Handler)),
        BuildLeaf.keyed(r_2_key, (key) => DelegateState(messageHandler: state2Handler)),
      ]);
}
