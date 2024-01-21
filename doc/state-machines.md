Once a state tree has been defined, a state machine can be created.

```dart
var stateTree = defineStateTree();
var stateMachine = TreeStateMachine(stateTree);
```

## Starting a state machine
Before messages can be sent to the state machine for processing, it has be started. The `start` 
method returns a future that yields a `CurrentState` that serves as a proxy to the current state 
after the machine has fully started.

```dart
var currentState = await stateMachine.start();
```

Once the state machine has started, the current state will be the state that was selected by 
following the initial child path, starting from the root state, as defined by the state tree.


## Sending messages
Once a state machine has started, a message may be dispatched to the current leaf state using the 
`post` method of `CurrentState`. This returns a future that completes when the message has been 
processed and any resulting transition has completed. Note that any object can be posted, there is 
no requirement for a common message base class. 

```dart
var message = SubmitCredentials(username: 'foo', password: 'bar');
ProcessedMessage messageResult = await currentState.post(message);
```
The `ProcessedMessage` base class describes how the message was processed. Further information about
what occurred by pattern matching on its subclases `HandledMessge`, `UnhandledMessage`, and 
`FailedMessage`. 


## State machine streams
In addition to inspecting the results of `post` to learn about how a message was processed, it is 
also possible to subscribe to several stream properties of `TreeStateMachine`:

* `processedMessages` yields an event for every message that is processed by the tree, whether or 
not the message was handled successfully, and whether or not a transition occurred as a result of 
the message.
* `handledMessages` is a convenience stream that yield an event when only when a message is 
successfully handled. Note that the HandledMessage event is also emitted on the processedMessages 
stream.
* `transitions` yields an event each time a transition between states occurs.

### Data streams
Both `TreeStateMachine` and `CurrentState` have a `dataStream` method. This returns a `ValueStream`
for a data state, allowing an application to observe changes to state data over time. 

```dart
// Observe changes to state data for the 'register' data state. 
var subscription = await stateMachine
   .dataStream(States.register)
   .listen((RegisterData data) {
      print(data.email);
   });
```


While both methods can return a stream, they differ slightly in their use:

* `CurrentState.dataStream` returns a stream for an *active* data state. If the requested state is 
not active, `null` is returned.  Additionally, the returned stream will complete when the state is 
no longer active (in other words, after the `onExit` notification for the state).
* `TreeStateMachine.dataStream` returns a stream, regardless of whether the requested data state is
active or not. This can be usedful for observing state data over the full lifetime of the state 
machine. A consequence of this is that the stream will does not complete unless the state machine is
stopped, so it may necessary for an app to explicitly cancel a subscription, depending on the 
circumstances. 


## Ending a state machine
A state machine can end in two ways.
* When processing a message, if the state machine transitions to a final state, then no other 
message processing or state transitions will occur, and the state machine has ended. This is called 
an 'internal stop'.
* Calling `stop` on the state machine will transition the machine to an implicit final state, 
identified by `stoppedStateKey`. This state will always be available, and does not need to be added 
when defining a state tree. This is called an 'external stop'.
   ```dart
   await stateMachine.stop();
   // done will be true after stopping.
   var done = stateMachine.isDone;
   ```

## State machine logging
The `tree_state_machine` package logs diagnostic messages using the Dart SDK `logging` package. In 
order to view this output in the Dart developer console: 

* Set `hierarchicalLoggingEnabled` from the `logging` package to `true` before creating a state
machine
* Set `developerLoggingEnabled` to `true` when creating the state machine.
