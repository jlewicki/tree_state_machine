// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/tree_builders.dart';

import 'state_data.dart';

final r_key = StateKey('r');
final r_a_key = StateKey('r_a');
final r_a_a_key = StateKey('r_a_a');
final r_a_1_key = StateKey('r_a_1');
final r_a_a_1_key = StateKey('r_a_a_1');
final r_a_a_2_key = StateKey('r_a_a_2');
final r_b_key = StateKey('r_b');
final r_b_1_key = StateKey('r_b_1');
final r_c_key = StateKey('r_c');
final r_c_a_key = StateKey('r_c_a');
final r_c_a_1_key = StateKey('r_c_a_1');
final r_X_key = StateKey('r_X');

StateTreeBuilder treeBuilder({
  TransitionHandler Function(StateKey key)? createEntryHandler,
  TransitionHandler Function(StateKey key)? createExitHandler,
  MessageHandler Function(StateKey key)? createMessageHandler,
  Object Function() Function(StateKey key)? createInitialDataValues,
  Map<StateKey, TransitionHandler>? entryHandlers,
  Map<StateKey, MessageHandler>? messageHandlers,
  Map<StateKey, TransitionHandler>? exitHandlers,
  Map<StateKey, Object Function()>? initialDataValues,
}) {
  final _createEntryHandler = createEntryHandler ?? (_) => emptyTransitionHandler;
  final _createExitHandler = createExitHandler ?? (_) => emptyTransitionHandler;
  final _createMessageHandler = createMessageHandler ?? (_) => emptyMessageHandler;
  final _entryHandlers = entryHandlers ?? {};
  final _messageHandlers = messageHandlers ?? {};
  final _exitHandlers = exitHandlers ?? {};
  final _initialDataValueCreators = initialDataValues ?? {};

  void Function(StateBuilder) buildState(StateKey key) {
    return (b) {
      b.runOnMessage(_messageHandlers[key] ?? _createMessageHandler(key));
      b.runOnEnter(_entryHandlers[key] ?? _createEntryHandler(key));
      b.runOnExit(_exitHandlers[key] ?? _createExitHandler(key));
    };
  }

  void Function(DataStateBuilder<D>) buildDataState<D>(StateKey key) {
    return (b) {
      b.runOnMessage(_messageHandlers[key] ?? _createMessageHandler(key));
      b.runOnEnter(_entryHandlers[key] ?? _createEntryHandler(key));
      b.runOnExit(_exitHandlers[key] ?? _createExitHandler(key));
    };
  }

  void Function(FinalStateBuilder) buildFinalState(StateKey key) {
    return (b) {
      b.runOnEnter(_entryHandlers[key] ?? _createEntryHandler(key));
    };
  }

  D Function() buildInitialDataValue<D>(StateKey key, D defaultValue) {
    return () {
      if (createInitialDataValues != null) return createInitialDataValues(key)() as D;
      if (_initialDataValueCreators[key] != null) {
        return _initialDataValueCreators[key]!() as D;
      }
      // if (_initialDataValues[key] != null) {
      //   return _initialDataValues[key] as D;
      // }
      return defaultValue;
    };
  }

  var b = StateTreeBuilder.withDataRoot<SpecialDataD>(
    r_key,
    InitialData(buildInitialDataValue(
        r_key,
        SpecialDataD()
          ..playerName = 'player'
          ..startYear = 2000)),
    buildDataState<SpecialDataD>(r_key),
    InitialChild(r_a_key),
    codec: SpecialDataD.codec,
  );

  b.finalState(r_X_key, buildFinalState(r_X_key));

  b.dataState<ImmutableData>(
    r_a_key,
    InitialData(buildInitialDataValue(
        r_a_key,
        ImmutableData((b) => b
          ..name = 'r_a'
          ..price = 20))),
    buildDataState<ImmutableData>(r_a_key),
    parent: r_key,
    initialChild: InitialChild(r_a_a_key),
    codec: ImmutableData.codec,
  );

  b.dataState<LeafDataBase>(
    r_a_a_key,
    InitialData(buildInitialDataValue(r_a_a_key, LeafDataBase()..name = 'leaf data base')),
    buildDataState<LeafDataBase>(r_a_a_key),
    parent: r_a_key,
    initialChild: InitialChild(r_a_a_2_key),
    codec: LeafDataBase.codec,
  );

  b.dataState<LeafData1>(
    r_a_a_1_key,
    InitialData(buildInitialDataValue(r_a_a_1_key, LeafData1()..counter = 1)),
    buildDataState<LeafData1>(r_a_a_1_key),
    parent: r_a_a_key,
    codec: LeafData1.codec,
  );

  b.dataState<LeafData2>(
    r_a_a_2_key,
    InitialData(buildInitialDataValue(r_a_a_2_key, LeafData2()..label = 'leaf data')),
    buildDataState<LeafData2>(r_a_a_2_key),
    parent: r_a_a_key,
    codec: LeafData2.codec,
  );

  b.dataState<ImmutableData>(
    r_a_1_key,
    InitialData(buildInitialDataValue(
        r_a_1_key,
        ImmutableData((b) => b
          ..name = 'r_a_1'
          ..price = 10))),
    buildDataState<ImmutableData>(r_a_1_key),
    parent: r_a_key,
    codec: ImmutableData.codec,
  );

  b.state(r_b_key, buildState(r_b_key), parent: r_key, initialChild: InitialChild(r_b_1_key));
  b.state(r_b_1_key, buildState(r_b_1_key), parent: r_b_key);

  b.dataState<ReadOnlyData>(
    r_c_key,
    InitialData(buildInitialDataValue(r_c_key, ReadOnlyData('r_c', 1))),
    buildDataState<ReadOnlyData>(r_c_key),
    parent: r_key,
    initialChild: InitialChild(r_c_a_key),
    codec: ReadOnlyData.codec,
  );

  b.dataState<ReadOnlyData>(
    r_c_a_key,
    InitialData(buildInitialDataValue(r_c_a_key, ReadOnlyData('r_c_a', 2))),
    buildDataState<ReadOnlyData>(r_c_a_key),
    parent: r_c_key,
    initialChild: InitialChild(r_c_a_1_key),
    codec: ReadOnlyData.codec,
  );

  b.state(r_c_a_1_key, buildState(r_c_a_1_key), parent: r_c_a_key);

  return b;
}
