import 'package:tree_state_machine/src/tree_state.dart';

class StateTreeNode {
  final TreeState state;
  final StateTreeNode parent;
  final List<StateTreeNode> children;
  StateTreeNode(this.state, this.parent, this.children) {}
}
