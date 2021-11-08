import 'package:tree_state_machine/src/machine/tree_state.dart';

final rootState = StateKey('root');
final state1 = StateKey('s1');
final state2 = StateKey('s2');
final state3 = StateKey('s3');

class StateData {
  String val = '0';
}

class StateData2 {
  int val = 0;
}

class Message {
  String val = 'msg';
}
