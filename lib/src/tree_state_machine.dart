import 'package:tree_state_machine/src/tree_state.dart';

class _StateTreeNode {
  final TreeState state;
  final _StateTreeNode parent;
  final List<_StateTreeNode> children;
  _StateTreeNode(this.state, this.parent, this.children) {}
}

class TreeStateMachine {
  Map<Type, _StateTreeNode> nodesByType;
  TreeState _currentState;
  StateHandler _currentHandler;

  get currentState => _currentState;

  Future<MessageResult> send(Object message) async {
    var ctx = MessageContext(message);
    var msgResult = await _currentHandler.onMessage(ctx);
    return msgResult;
  }
}
