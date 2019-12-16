import 'package:tree_state_machine/src/helpers.dart';
import 'package:tree_state_machine/src/builders/tree_builders.dart';
import 'package:tree_state_machine/src/tree_node.dart';
import 'package:tree_state_machine/src/tree_node_builder.dart';
import 'package:tree_state_machine/src/tree_state.dart';

final r_key = StateKey.named('root');
final r_1_key = StateKey.named('leaf1');
final r_2_key = StateKey.named('leaf2');

final leaves = [
  Leaf(key: r_1_key, createState: (key) => DelegateState()),
  Leaf(key: r_2_key, createState: (key) => DelegateState()),
];

NodeBuilder<RootNode> treeBuilder({
  MessageHandler rootHandler,
  MessageHandler state1Handler,
  MessageHandler state2Handler,
}) {
  return Root(
      key: r_key,
      createState: (key) => DelegateState(messageHandler: rootHandler),
      initialChild: (_) => r_1_key,
      children: [
        Leaf(key: r_1_key, createState: (key) => DelegateState(messageHandler: state1Handler)),
        Leaf(key: r_2_key, createState: (key) => DelegateState(messageHandler: state2Handler)),
      ]);
}
