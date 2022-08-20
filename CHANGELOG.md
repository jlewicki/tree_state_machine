## 2.2.1
- Add `action` parameter to `enterChannel` builder method.
## 2.2.0
- Add suppport for rethrowing exceptions with `PostMessageErrorPolicy`.
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
- Adjust signature of `schedule` methods to emphasize that the message function is called each time timer elapses.

## 1.0.1
- Initial version.
