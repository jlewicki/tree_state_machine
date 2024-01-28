// ignore_for_file: constant_identifier_names, non_constant_identifier_names

import 'dart:async';

import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

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

StateTree treeBuilder({
  TransitionHandler Function(StateKey key)? createEntryHandler,
  TransitionHandler Function(StateKey key)? createExitHandler,
  MessageHandler Function(StateKey key)? createMessageHandler,
  FutureOr<Object?> Function(TransitionContext ctx)? Function(StateKey key)?
      createInitialDataValues,
  Map<StateKey, TransitionHandler>? entryHandlers,
  Map<StateKey, MessageHandler>? messageHandlers,
  Map<StateKey, TransitionHandler>? exitHandlers,
  Map<StateKey, List<TreeStateFilter>>? filters,
  Map<StateKey, FutureOr<Object> Function()>? initialDataValues,
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

  GetInitialData<D?> buildInitialDataValue<D>(StateKey key, D defaultValue) {
    return (TransitionContext transCtx) {
      if (createInitialDataValues != null) {
        var creator = createInitialDataValues(key);
        if (creator != null) {
          return creator.call(transCtx) as FutureOr<D?>;
        }
      }
      if (initialDataValueCreators[key] != null) {
        return initialDataValueCreators[key]!() as FutureOr<D>;
      }
      return defaultValue;
    };
  }

  MessageHandler messageHandler_(StateKey key) {
    return messageHandlers_[key] ?? createMessageHandler_(key);
  }

  TransitionHandler entryHandler_(StateKey key) {
    return entryHandlers_[key] ?? createEntryHandler_(key);
  }

  TransitionHandler exitHandler_(StateKey key) {
    return exitHandlers_[key] ?? createExitHandler_(key);
  }

  State buildState(
    StateKey key, {
    InitialChild? initialChild,
    List<StateConfig>? childStates,
  }) {
    return initialChild != null
        ? State.composite(
            key,
            initialChild,
            onEnter: entryHandler_(key),
            onMessage: messageHandler_(key),
            onExit: exitHandler_(key),
            childStates: childStates!,
            filters: filters_[key] ?? [],
          )
        : State(
            key,
            onEnter: entryHandler_(key),
            onMessage: messageHandler_(key),
            onExit: exitHandler_(key),
            filters: filters_[key] ?? [],
          );
  }

  DataState<D> buildDataState<D>(
    DataStateKey<D> key,
    InitialData<D> initialData, {
    InitialChild? initialChild,
    List<StateConfig>? childStates,
    StateDataCodec<D>? codec,
  }) {
    return initialChild != null
        ? DataState.composite(
            key,
            initialData,
            initialChild,
            onEnter: entryHandler_(key),
            onMessage: messageHandler_(key),
            onExit: exitHandler_(key),
            childStates: childStates!,
            codec: codec,
            filters: filters_[key] ?? [],
          )
        : DataState(
            key,
            initialData,
            onEnter: entryHandler_(key),
            onMessage: messageHandler_(key),
            onExit: exitHandler_(key),
            codec: codec,
            filters: filters_[key] ?? [],
          );
  }

  var tree = StateTree.dataRoot<SpecialDataD>(
    r_key,
    InitialData.run(buildInitialDataValue(
        r_key,
        SpecialDataD()
          ..playerName = 'player'
          ..startYear = 2000)),
    InitialChild(r_a_key),
    onEnter: entryHandler_(r_key),
    onMessage: messageHandler_(r_key),
    onExit: exitHandler_(r_key),
    codec: SpecialDataD.codec,
    filters: filters_[r_key] ?? [],
    childStates: [
      buildDataState<ImmutableData>(
        r_a_key,
        InitialData.run(buildInitialDataValue(
          r_a_key,
          ImmutableData(name: 'r_a', price: 20),
        )),
        initialChild: InitialChild(r_a_a_key),
        codec: ImmutableData.codec,
        childStates: [
          buildDataState<LeafDataBase>(
            r_a_a_key,
            InitialData.run(buildInitialDataValue(
              r_a_a_key,
              LeafDataBase()..name = 'leaf data base',
            )),
            initialChild: InitialChild(r_a_a_2_key),
            codec: LeafDataBase.codec,
            childStates: [
              buildDataState<LeafData1>(
                r_a_a_1_key,
                InitialData.run(buildInitialDataValue(
                  r_a_a_1_key,
                  LeafData1()..counter = 1,
                )),
                codec: LeafData1.codec,
              ),
              buildDataState<LeafData2>(
                r_a_a_2_key,
                InitialData.run(buildInitialDataValue(
                  r_a_a_2_key,
                  LeafData2()..label = 'leaf data',
                )),
                codec: LeafData2.codec,
              ),
            ],
          ),
          buildDataState<ImmutableData>(
            r_a_1_key,
            InitialData.run(buildInitialDataValue(
              r_a_1_key,
              ImmutableData(name: 'r_a_1', price: 10),
            )),
            codec: ImmutableData.codec,
          ),
        ],
      ),
      buildState(
        r_b_key,
        initialChild: InitialChild(r_b_1_key),
        childStates: [
          buildState(
            r_b_1_key,
          ),
          buildDataState<int>(
            r_b_2_key,
            InitialData.run(buildInitialDataValue(r_b_2_key, 2)),
          ),
        ],
      ),
      buildDataState<ReadOnlyData>(
        r_c_key,
        InitialData.run(buildInitialDataValue(r_c_key, ReadOnlyData('r_c', 1))),
        initialChild: InitialChild(r_c_a_key),
        codec: ReadOnlyData.codec,
        childStates: [
          buildDataState<ReadOnlyData>(
            r_c_a_key,
            InitialData.run(
                buildInitialDataValue(r_c_a_key, ReadOnlyData('r_c_a', 2))),
            initialChild: InitialChild(r_c_a_1_key),
            codec: ReadOnlyData.codec,
            childStates: [
              buildState(
                r_c_a_1_key,
              ),
            ],
          ),
        ],
      ),
    ],
    finalStates: [
      FinalState(
        r_X_key,
        onEnter: entryHandler_(r_X_key),
      ),
      FinalDataState(
        r_XD_key,
        InitialData.run(
            buildInitialDataValue(r_XD_key, FinalData()..counter = 1)),
        onEnter: entryHandler_(r_XD_key),
      ),
    ],
  );

  return tree;
}
