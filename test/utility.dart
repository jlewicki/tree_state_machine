import 'package:test/test.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

extension TreeNodeTestingExtensions on TreeNode {
  bool get isLeaf => this is LeafTreeNode;
  bool get isInterior => this is InteriorTreeNode;
  List<TreeNode> get children =>
      switch (this) { CompositeTreeNode(children: var c) => c, _ => [] };
}

final throwsStateMachineError = throwsA(isA<StateMachineError>());
