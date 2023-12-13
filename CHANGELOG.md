## 3.0.0
- Adjust parameter order of `StateTreeBuilder.withRoot` and `StateTreeBuilder.withDataRoot`
- Add `ValueSubject.mapValueStream`.
- Change return type of `TreeStateMachine.lifecycle` to `ValueStream`, and remove redundant getters for specific 
  lifecycle states.
- Change return type of `TreeStateMachine.loadFrom` to `Future<CurrentState>`.
- Add `metadata` to `TransistionContext` and `MessageContext.goTo`.
- Add `TreeStateMachine.currentState`.
- Add `TreeNodeInfo.getChildren`.
- Add `TreeStateMachine.rootNode`.
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
- Rename `MessageContext.appData` -> - `MessageContext.metadata`.
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
