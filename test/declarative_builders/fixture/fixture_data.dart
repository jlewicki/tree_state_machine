import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';

StreamSubscription<LogRecord> enableLogging() {
  Logger.root.level = Level.ALL;
  return Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}

final rootState = StateKey('root');
final state1 = StateKey('s1');
final state2 = StateKey('s2');
final state3 = StateKey('s3');
final state4 = StateKey('s4');
final state5 = StateKey('s5');

class StateData {
  String val = '0';
}

class StateData2 {
  int val = 0;
}

class Message {
  String val = 'msg';
}

class Message2 {
  int val = 1;
}
