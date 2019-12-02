import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r_key = StateKey.named('root');
final r_1_key = StateKey.named('leaf1');
final r_2_key = StateKey.named('leaf2');

final leaves = [
  buildLeaf(key: r_1_key, createState: (key) => DelegateState()),
  buildLeaf(key: r_2_key, createState: (key) => DelegateState()),
];

RootNodeBuilder treeBuilder({
  MessageHandler rootHandler,
  MessageHandler state1Handler,
  MessageHandler state2Handler,
}) {
  return buildRoot(
      key: r_key,
      state: (key) => DelegateState(messageHandler: rootHandler),
      initialChild: (_) => r_1_key,
      children: [
        buildLeaf(key: r_1_key, createState: (key) => DelegateState(messageHandler: state1Handler)),
        buildLeaf(key: r_2_key, createState: (key) => DelegateState(messageHandler: state2Handler)),
      ]);
}
