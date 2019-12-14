import 'package:tree_state_machine/src/data_provider.dart';
import 'package:tree_state_machine/src/tree_builders.dart';
import 'package:tree_state_machine/src/tree_state.dart';

import 'tree_data.dart';

final r_key = StateKey.named('r');
final r_a_key = StateKey.named('r_a');
final r_a_a_key = StateKey.named('r_a_a');
final r_a_1_key = StateKey.named('r_a_1');
final r_a_a_1_key = StateKey.named('r_a_a_1');
final r_a_a_2_key = StateKey.named('r_a_a_2');
final r_b_key = StateKey.named('r_b');
final r_b_1_key = StateKey.named('r_b_1');
final r_X_key = StateKey.named('r_X');

RootNodeBuilder treeBuilder({
  TransitionHandler createEntryHandler(StateKey key),
  TransitionHandler createExitHandler(StateKey key),
  MessageHandler createMessageHandler(StateKey key),
  Map<StateKey, TransitionHandler> entryHandlers,
  Map<StateKey, MessageHandler> messageHandlers,
  Map<StateKey, TransitionHandler> exitHandlers,
  Map<StateKey, Object> initialDataValues,
  Map<StateKey, DataProvider> dataProviders,
}) {
  final _createEntryHandler = createEntryHandler ?? (_) => emptyTransitionHandler;
  final _createExitHandler = createExitHandler ?? (_) => emptyTransitionHandler;
  final _createMessageHandler = createMessageHandler ?? (_) => emptyMessageHandler;
  final _entryHandlers = entryHandlers ?? {};
  final _messageHandlers = messageHandlers ?? {};
  final _exitHandlers = exitHandlers ?? {};
  final _initialDataValues = initialDataValues ?? {};
  final _dataProviders = dataProviders ?? {};

  TreeState createState(StateKey key) => DelegateState(
        entryHandler: _entryHandlers[key] ?? _createEntryHandler(key),
        messageHandler: _messageHandlers[key] ?? _createMessageHandler(key),
        exitHandler: _exitHandlers[key] ?? _createExitHandler(key),
      );

  DataTreeState<D> createDataState<D>(StateKey key) => DelegateDataState<D>(
        entryHandler: _entryHandlers[key] ?? _createEntryHandler(key),
        messageHandler: _messageHandlers[key] ?? _createMessageHandler(key),
        exitHandler: _exitHandlers[key] ?? _createExitHandler(key),
      );

  DataProvider<D> createDataProvider<D>(StateKey key, DataProvider<D> Function() defaultProvider) =>
      _dataProviders[key] ?? defaultProvider();

  return dataRootBuilder(
    key: r_key,
    createState: (k) => createDataState<SpecialDataD>(k),
    provider: createDataProvider<SpecialDataD>(
      r_key,
      () => SpecialDataD.dataProvider(_initialDataValues[r_key]),
    ),
    initialChild: (_) => r_a_key,
    finalStates: [
      finalBuilder(key: r_X_key, createState: (key) => DelegateFinalState(_exitHandlers[key])),
    ],
    children: [
      dataInteriorBuilder(
        key: r_a_key,
        createState: (k) => createDataState<ImmutableData>(k),
        provider: createDataProvider<ImmutableData>(
          r_a_key,
          () => ImmutableData.dataProvider(_initialDataValues[r_a_key]),
        ),
        initialChild: (_) => r_a_a_key,
        children: [
          dataInteriorBuilder(
            key: r_a_a_key,
            createState: (k) => createDataState<LeafDataBase>(k),
            provider: createDataProvider<LeafDataBase>(
              r_a_a_key,
              () => LeafDataBase.dataProvider(),
            ),
            initialChild: (_) => r_a_a_2_key,
            children: [
              dataLeafBuilder(
                key: r_a_a_1_key,
                createState: (k) => createDataState<LeafData1>(k),
                provider: createDataProvider<LeafData1>(
                  r_a_a_1_key,
                  () => LeafData1.dataProvider(_initialDataValues[r_a_a_1_key]),
                ) as OwnedDataProvider<LeafData1>,
              ),
              dataLeafBuilder(
                key: r_a_a_2_key,
                createState: (k) => createDataState<LeafData2>(k),
                provider: createDataProvider<LeafData2>(
                  r_a_a_2_key,
                  () => LeafData2.dataProvider(_initialDataValues[r_a_a_2_key]),
                ) as OwnedDataProvider<LeafData2>,
              ),
            ],
          ),
          dataLeafBuilder(
            key: r_a_1_key,
            createState: (k) => createDataState<ImmutableData>(k),
            provider: createDataProvider<ImmutableData>(
              r_a_1_key,
              () => ImmutableData.dataProvider(_initialDataValues[r_a_1_key]),
            ) as OwnedDataProvider<ImmutableData>,
          ),
        ],
      ),
      interiorBuilder(
        key: r_b_key,
        createState: createState,
        initialChild: (_) => r_b_1_key,
        children: [
          leafBuilder(key: r_b_1_key, createState: createState),
        ],
      ),
    ],
  );
}
