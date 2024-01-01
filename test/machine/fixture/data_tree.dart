// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/declarative_builders.dart';

import 'state_data.dart';

final r_key = DataStateKey<SpecialDataD>('r');
final r_a_key = DataStateKey<ImmutableData>('r_a');
final r_a_a_key = DataStateKey<LeafDataBase>('r_a_a');
final r_a_1_key = DataStateKey<ImmutableData>('r_a_1');
final r_a_a_1_key = DataStateKey<LeafData1>('r_a_a_1');
final r_a_a_2_key = DataStateKey<LeafData2>('r_a_a_2');
final r_b_key = StateKey('r_b');
final r_b_1_key = StateKey('r_b_1');
final r_b_2_key = DataStateKey<int>('r_b_2');
final r_c_key = DataStateKey<ReadOnlyData>('r_c');
final r_c_a_key = DataStateKey<ReadOnlyData>('r_c_a');
final r_c_a_1_key = StateKey('r_c_a_1');
final r_X_key = StateKey('r_X');
final r_XD_key = DataStateKey<FinalData>('r_XD');

DeclarativeStateTreeBuilder treeBuilder({
  TransitionHandler Function(StateKey key)? createEntryHandler,
  TransitionHandler Function(StateKey key)? createExitHandler,
  MessageHandler Function(StateKey key)? createMessageHandler,
  Object Function() Function(StateKey key)? createInitialDataValues,
  Map<StateKey, TransitionHandler>? entryHandlers,
  Map<StateKey, MessageHandler>? messageHandlers,
  Map<StateKey, TransitionHandler>? exitHandlers,
  Map<StateKey, List<TreeStateFilter>>? filters,
  Map<StateKey, Object Function()>? initialDataValues,
}) {
  final createEntryHandler_ =
      createEntryHandler ?? (_) => emptyTransitionHandler;
  final createExitHandler_ = createExitHandler ?? (_) => emptyTransitionHandler;
  final createMessageHandler_ =
      createMessageHandler ?? (_) => emptyMessageHandler;
  final entryHandlers_ = entryHandlers ?? {};
  final messageHandlers_ = messageHandlers ?? {};
  final exitHandlers_ = exitHandlers ?? {};
  final initialDataValueCreators = initialDataValues ?? {};
  final filters_ = filters ?? {};

  void Function(StateBuilder<void>) buildState(StateKey key) {
    return (b) {
      b.handleOnMessage(messageHandlers_[key] ?? createMessageHandler_(key));
      b.handleOnEnter(entryHandlers_[key] ?? createEntryHandler_(key));
      b.handleOnExit(exitHandlers_[key] ?? createExitHandler_(key));
    };
  }

  void Function(StateBuilder<D>) buildDataState<D>(StateKey key) {
    return (b) {
      b.handleOnMessage(messageHandlers_[key] ?? createMessageHandler_(key));
      b.handleOnEnter(entryHandlers_[key] ?? createEntryHandler_(key));
      b.handleOnExit(exitHandlers_[key] ?? createExitHandler_(key));
    };
  }

  void Function(EnterStateBuilder<void>) buildFinalState(StateKey key) {
    return (b) {
      b.handleOnEnter(entryHandlers_[key] ?? createEntryHandler_(key));
    };
  }

  void Function(EnterStateBuilder<D>) buildFinalDataState<D>(StateKey key) {
    return (b) {
      b.handleOnEnter(entryHandlers_[key] ?? createEntryHandler_(key));
    };
  }

  D Function() buildInitialDataValue<D>(StateKey key, D defaultValue) {
    return () {
      if (createInitialDataValues != null) {
        return createInitialDataValues(key)() as D;
      }
      if (initialDataValueCreators[key] != null) {
        return initialDataValueCreators[key]!() as D;
      }
      return defaultValue;
    };
  }

  var builder = DeclarativeStateTreeBuilder.withDataRoot<SpecialDataD>(
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

  builder.finalState(r_X_key, buildFinalState(r_X_key));

  builder.finalDataState<FinalData>(
    r_XD_key,
    InitialData(buildInitialDataValue(r_XD_key, FinalData()..counter = 1)),
    buildFinalDataState(r_XD_key),
  );

  builder
      .dataState<ImmutableData>(
        r_a_key,
        InitialData(buildInitialDataValue(
            r_a_key, ImmutableData(name: 'r_a', price: 20))),
        buildDataState<ImmutableData>(r_a_key),
        parent: r_key,
        initialChild: InitialChild(r_a_a_key),
        codec: ImmutableData.codec,
      )
      .filters(filters_[r_a_key] ?? []);

  builder
      .dataState<LeafDataBase>(
        r_a_a_key,
        InitialData(buildInitialDataValue(
            r_a_a_key, LeafDataBase()..name = 'leaf data base')),
        buildDataState<LeafDataBase>(r_a_a_key),
        parent: r_a_key,
        initialChild: InitialChild(r_a_a_2_key),
        codec: LeafDataBase.codec,
      )
      .filters(filters_[r_a_a_key] ?? []);

  builder
      .dataState<LeafData1>(
        r_a_a_1_key,
        InitialData(
            buildInitialDataValue(r_a_a_1_key, LeafData1()..counter = 1)),
        buildDataState<LeafData1>(r_a_a_1_key),
        parent: r_a_a_key,
        codec: LeafData1.codec,
      )
      .filters(filters_[r_a_a_1_key] ?? []);

  builder
      .dataState<LeafData2>(
        r_a_a_2_key,
        InitialData(buildInitialDataValue(
            r_a_a_2_key, LeafData2()..label = 'leaf data')),
        buildDataState<LeafData2>(r_a_a_2_key),
        parent: r_a_a_key,
        codec: LeafData2.codec,
      )
      .filters(filters_[r_a_a_2_key] ?? []);

  builder
      .dataState<ImmutableData>(
        r_a_1_key,
        InitialData(buildInitialDataValue(
            r_a_1_key, ImmutableData(name: 'r_a_1', price: 10))),
        buildDataState<ImmutableData>(r_a_1_key),
        parent: r_a_key,
        codec: ImmutableData.codec,
      )
      .filters(filters_[r_a_1_key] ?? []);

  builder
      .state(
        r_b_key,
        buildState(r_b_key),
        parent: r_key,
        initialChild: InitialChild(r_b_1_key),
      )
      .filters(filters_[r_b_key] ?? []);
  builder
      .state(
        r_b_1_key,
        buildState(r_b_1_key),
        parent: r_b_key,
      )
      .filters(filters_[r_b_1_key] ?? []);
  builder
      .dataState<int>(
        r_b_2_key,
        InitialData(buildInitialDataValue(r_b_2_key, 2)),
        buildState(r_b_2_key),
        parent: r_b_key,
      )
      .filters(filters_[r_b_2_key] ?? []);

  builder
      .dataState<ReadOnlyData>(
        r_c_key,
        InitialData(buildInitialDataValue(r_c_key, ReadOnlyData('r_c', 1))),
        buildDataState<ReadOnlyData>(r_c_key),
        parent: r_key,
        initialChild: InitialChild(r_c_a_key),
        codec: ReadOnlyData.codec,
      )
      .filters(filters_[r_c_key] ?? []);

  builder
      .dataState<ReadOnlyData>(
        r_c_a_key,
        InitialData(buildInitialDataValue(r_c_a_key, ReadOnlyData('r_c_a', 2))),
        buildDataState<ReadOnlyData>(r_c_a_key),
        parent: r_c_key,
        initialChild: InitialChild(r_c_a_1_key),
        codec: ReadOnlyData.codec,
      )
      .filters(filters_[r_c_a_key] ?? []);

  builder
      .state(
        r_c_a_1_key,
        buildState(r_c_a_1_key),
        parent: r_c_a_key,
      )
      .filters(filters_[r_c_a_1_key] ?? []);

  return builder;
}
