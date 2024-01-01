import 'package:test/test.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// extension TreeNodeTestingExtensions on TreeNode {
//   bool get isLeaf => this is LeafNode;
//   bool get isInterior => this is InteriorNode;
//   List<TreeNode> get children =>
//       switch (this) { CompositeNode(children: var c) => c, _ => [] };
// }

final throwsStateMachineError = throwsA(isA<StateMachineError>());
