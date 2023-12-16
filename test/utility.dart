import 'package:tree_state_machine/src/machine/tree_node.dart';

extension TreeNodeTestingExtensions on TreeNode {
  bool get isLeaf => this is LeafTreeNode;
  bool get isInterior => this is InteriorTreeNode;
  List<TreeNode> get children =>
      switch (this) { CompositeTreeNode(children: var c) => c, _ => [] };
  // bool get isFinalLeaf =>
  //     switch (this) { LeafTreeNode(isFinalState: true) => true, _ => false };
}
