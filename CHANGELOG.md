## 3.1.0
- Changed return type of `GetInitialData<D>` to `FutureOr<D>`, to allow async initial data.

## 3.0.1
- Rename `TreeStateMachine.developerLoggingEnabled` -> `TreeStateMachine.enableDeveloperLogging` 
(which was meant to be in 3.0.0 :( ) 

## 3.0.0
- Upgrade to Dart3 SDK
- Added `TransitionContext.redirectTo`.
- Added `delegate_builders` library.
- Remove `declarative_builders` library. It is moved to `tree_state_builders` package.
- Added `DataStateKey` to reinforce association between a data state and its state data type.
- Added `TreeStateFilter`.
- Simplify logging with `enableDeveloperLogging`.

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
