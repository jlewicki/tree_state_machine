## 3.0.0-dev.10
- Significant reorganization of builder classes (again). Added `delegate_builders` library.
- Require a `DataStateKey` when accessing state data. Lookups by type alone are no longer supported.
- `MessageContext.data` and `TransitionContext.data` no longer can return a null value.

## 3.0.0-dev.9
- Change type of `key` parameter of `DeclarativeStateTreeBuilder.machineState` to `DataStateKey<NestedMachineData>`

## 3.0.0-dev.8
- Expose `TreeNodeBuildInfo` from `NodeBuildInfoBuilder` (should have been in previous release)

## 3.0.0-dev.7
- Add `extendNodes` parameter to `TreeBuildContext` constructor allowing metadata and filters to be
applied to tree nodes as they are constructed. 
- Rename `TreeStateMachine.fromTreeBuilder` -> `TreeStateMachine.withTreeBuilder`
- Add methods to `TreeNodeInfoNavigationExtensions` to traverse `TreeNodeInfo` hierarchy.

## 3.0.0-dev.6
- Significant reorganization of builder classes. `tree_builders` library is split into `build` and 
  `declarative_builders` libraries.
- Rename `logName` -> `logSuffix` in `TreeStateMachine` constructor.

## 3.0.0-dev.5
- Adjust parameter order of `StateTreeBuilder.withRoot` and `StateTreeBuilder.withDataRoot`
- Add `ValueSubject.mapValueStream`.
- Change return type of `TreeStateMachine.lifecycle` to `ValueStream`, and remove redundant getters for specific 
  lifecycle states.
- Change return type of `TreeStateMachine.loadFrom` to `Future<CurrentState>`.
- Add `metadata` to `TransistionContext` and `MessageContext.goTo`.

## 3.0.0-dev.4
- Add `TreeStateMachine.currentState`.

## 3.0.0-dev.3
- Add `TreeStateMachine.isStarting`.
- Add `TreeNodeInfo.getChildren`.
- Experimental: Add `TreeStateMachine.rootNode`.

## 3.0.0-dev.2
- The `initialState` parameter of the `StateTreeBuilder` constructor was renamed to `initialChild` to reduce developer
  confusion, and the error message was improved when this parameter refers to an invalid state.
- `StateTreeDefinitionError` is thrown when validating a `StateTreeBuilder`, instead of [StateError].
- Remove `TreeStateMachine.startWith` and add optional named params to `TreeStateMachine.start`. Having two `start` type
  methods might be confusing. 
- Adjust parameters of the following to be `DataStateKey`, not `StateKey`:
   * `TreeStateMachine.dataStream` 
   * `CurrentState.data` 
   * `CurrentState.dataValue` 
   * `MessageContext.data`  
   * `TransitionContext.data` 
- Rename `CurrentState.data` -> `CurrentState.dataStream`.
- Add `TreeStateFilter`.
- Add `leafState`, `handlingState`, and `activeStates` to `MessageContext`.
- Add `handlingState` to `TransitionContext`.
- Rename `MessageContext.appData` -> `MessageContext.metadata`.

## 3.0.0-dev.1
- Upgrade to Dart3 SDK
- Add `DataStateKey` to emphasize association between a data state and its state data type.
- Add `TreeStateMachine.startWith` to enable starting a state machine with specific initial values.
  for data states.



## 2.4.0
- Fix issue with `MessageHandlerWhenBuilder` not evaluating multiple conditions correctly. 
- Fix issue with `MessageHandlerBuilder.action` not evaluating `actionResult` parameter correctly. 

## 2.3.0
- Rename `NestedMachineData.nestedState` -> `NestedMachineData.nestedCurrentState`.
- Add `label` property to `TreeStateMachine` and `TreeStateBuilder` for debugging purposes.
- Improve messages when an error occurs entering a channel.

## 2.2.1
- Add `action` parameter to `enterChannel` builder method.

## 2.2.0
- Add support for rethrowing exceptions with `PostMessageErrorPolicy`.
- Fix bug where data streams for `void` data states might not be completed when state exits.
- Add `StreamCombineLatest`.

## 2.1.1
- Add `const` Channel constructor.
- Add rootKey prop to StateTreeBuilder 
- Add handling of `void` state data.
- Additional API documentation.

## 2.0.1
- Adjustments and internal simplifications of tree_builders library.
- Add support for final data states.
- Add nested state machines.
- Adjust logging so that log messages can be named to reflect the state machine that emits them.

## 1.0.3
- Package updates to improve pub.dev score.
- Add logging when timers are canceled.

## 1.0.2
- Add more tests and documentation.
- Adjust signature of `schedule` methods to emphasize that the message function is called each time the timer elapses.

## 1.0.1
- Initial version.
