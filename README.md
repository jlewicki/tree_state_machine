# tree_state_machine

`tree_state_machine` is a Dart package that provides a simple and declarative way to define and 
execute a tree state machine.

## Tree state machines
A tree state machine is a similar to a traditional finite state machine (FSM), in 
that the state of a system is modeled by a set of discrete states, only one of which is current 
at any given time. The system can transition from one state to another as messages (typically 
representing some sort of external event) are processed by the current state.

In a tree state machine, unlike a traditional FSM, states are arranged into a tree, so that a state 
can have zero or more child states. If a state has no child states, it's called a leaf state, 
otherwise it's called a composite state. The advantage of this hierarchical relationship is that 
states can delegate message handling to their parent state, allowing one parent state to establish 
invariants and provide common message handling logic for any number of descendant states.

It is important to note that like a FSM, a tree state machine only has a single current state at any
given time. This implies that the current state is always a leaf state. While the parent states of the current state are not current, they are considered active. That is, they have been entered, but not yet exited, and therefore participate in message handling. 

# Getting Started
The primary API for the working with a tree state machine is provided by the `tree_state_machine`
library. The API for defining state trees is provided by `tree_builders` library. Depending on how
your application is structured, you will need to import one or both of these libraries:
```dart
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
```

# Defining a state tree

To define a new state tree, first create a `StateTreeBuilder`.
```dart
 var treeBuilder = StateTreeBuilder();
```

## Naming States
Each state in a state tree is uniquely identified by a `StateKey`. These keys are used when defining
states, and naming the destination state when a state transition occurs. For convenience, they are 
often grouped together into containing class.
```dart
class States {
  static const StateKey root = StateKey.named('Root');
  static const StateKey open = StateKey.named('Open');
  static const StateKey assigned = StateKey.named('Assigned'); 
}
```

## States
States are declared using the `state` method, passing a `StateKey` to identify the state.
```dart
treeBuilder.state(States.open);
```

### Data States
States often require additional data to model their behavior. For example, a 'counting' state might 
need an integer value to store the number of times an event occured. The data value(s) needed by a 
state are collectively referred to as state data (or more formally, extended state variables).  
  
A data state can be defined using the `dataState` method, providing the type of state data as a
type parameter. A function to create initial data value can be provided. 
```dart
treeBuilder.dataState<Bug>(
  States.root, 
  initialData: () => Bug()..title = 'New Bug',
);
```

Note that if a state requires multiple data values, those values should be combined in a single 
class, and that class should be used as the type parameter of `dataState`. 

In addition to managing and providing access to a data value, a data state supports  

  * Change notification of updated data values by publishing to an `Observable<D>`
  * Encoding/decoding of data in the active nodes of a state tree. This can be useful for saving and
    reloading state trees across application sessions.

### Final States
A state may be defined as a final state using the `finalState` method. Once a transition to a final
state occurs, no other state transitions or message processing will occur.
```dart
treeBuilder.finalState(StateKeys.historical);
```
Note that final states may never have any child states.

## Child States
A state can be defined as a child of another state using the `withParentMethod`. Once a state has 
been assigned a parent, the parent state must define which of its child states must be entered when 
the parent is entered using `withInitialChild`.
```dart
treeBuilder
  .state(States.open)
  .withParent(States.root);

treeBuilder
  .dataState<Bug>(States.root, initialData: () => Bug()..title = 'New Bug')
  .withInitialChild(States.open);
```

## Message Handlers
The way a state responds to a message is defined by the `onMessage` method. The message type is 
provided as a type parameter, and the behavior of the state when a message arrives is defined by a 
builder function. This function is passed a `MessageHandlerBuilder` that can be used to define the 
behavior, for example by calling the `goTo` method to indicate a transition to a different state 
should occur.
```dart
treeBuilder
  .state(States.open)
  .onMessage<Close>((b) => b.goTo(States.closed));
```
### Reading and writing state data
A state can use the `data` and `findData` methods of `MessageContext` to access the data value 
associated with a data state. `data` retrieves data by state key, and `findData` retrieves state 
data by type. In both cases a state can retrieve its own state data (it it is a data state), or the
state data of any of its ancestor states.
```dart
treeBuilder
      .state(States.open)
      .withParent(States.root)
      .onMessage<Close>((b) => b.goTo(
        States.closed, 
        before: (msg, ctx) async {
          var assignee = ctx.findData<Bug>().assignee;
          await logClosing(assignee); 
        },
      ));
```

State data can be updated using the `updateData` or `replaceData` methods of `MessageContext`.

In addition to accessing state data from a `MessageContext`, `MessageHandlerBuilder` has methods 
`updateData` and `replaceData` as shortcuts where state data should be updated in response to 
handling a message, instead of causing a state transition.


### Guard Conditions
The methods of `MessageHandlerBuilder` have an optional `when` parameter. If a function is provided
for this argument it will be called when a message arrives, and the message handler action will only
take place if the function yields `true`.
```dart
treeBuilder
  .state(States.open)
  .withParent(States.root)
  .onMessage<Close>((b) => b.goTo(
    States.closed,
    when: (msg, ctx) => ctx.findData<Bug>().assignee == 'admin@foo.com',
  ));
```

## Transition Handlers
Entry and exit handlers for a state are defined using the `onEnter` and `onExit` methods. A builder
function must be provided for specifying the behavior of the transition, and this function will be 
passed a `TransitionHandlerBuilder` that can be used to define the behavior.
```dart
treeBuilder
  .state(States.unassigned)
  .withParent(States.open)
  .onEnter<Bug, Object>((b) => b.updateData((data) => data.assignee = null));
```
`onEnter` has two type parameters. The first is the type of stata data expected by the 
state, and the second is the type of the payload expected in the `TransitionContext` when the state 
is entered. One or both can be typed as `Object` if the transition handler does not use them. For 
instance, in the example above a payload is not expected so the second type parameter is typed as
`Object`.

### Payloads and Entry Channels
When triggering a state transition it may be useful to provide additional information to the state 
that will be entered. This can be done by providing a `payload` function when calling `goTo`.
```dart
treeBuilder
  .state(States.deferred)
  .onMessage<Assign>((b) => b.goTo(States.assigned, payload: (msg, _) => msg.assignee));
```

`EntryChannel<P>` can be used establish a contract indictating that entering a particular state 
requires payload of a specific type. A channel value is shared both when triggering a state 
transition, and when the target state is entered. 
```dart
var channelAssigned = EntryChannel<String>(States.assigned);
```

A state transition is triggered by entering the channel.
```dart
treeBuilder
  .state(States.open)
  .onMessage<Assign>((b) => b.enterChannel(
    channelAssigned, 
    payload: (msg, _) => msg.assignee));
```

When the target state is entered, the payload value is enforced by providing the channel when 
calling one of the `TransitionHandlerBuilder` methods.  
```dart
treeBuilder
  .state(States.assigned)
  .onEnter<BugData, String>((b) => b.updateDataFromPayload(
    (data, payload) => data.assignee = payload,
    channel: channelAssigned));
``` 

## DOT Export
Calling `toDot` will return a string containing a description of the state tree in DOT graph language format. 
```dart
var dot = treeBuilder.toDot();
```

This text can be used as input to a tool that provides a visualization of a DOT graph, for example 
[www.webgraphviz.com](http://www.webgraphviz.com).   

# Using TreeStateMachine

## Starting a state machine
Once the state tree has been fully defined, it can be used to initialize a `TreeStateMachine`.
```dart
var stateMachine = TreeStateMachine(treeBuilder);
await stateMachine.start();
```
When the machine is started, the machine will determine a path of nodes, starting at the root and
ending at a leaf node, by recursively calling the `initialChild` function at each level of the tree
until a leaf node is reached. This path of nodes is called the initial path, and the machine will 
call `onEnter` for each state along this path.

When all the states along the path have been entered, the state of the leaf node at the end of the
path becomes the current state of the state machine, and messages may be sent to this state to be 
processed.


## Message processing
`sendMessage` can be used to send a message for processing by the current state.
```dart
var processed = await sm.currentState.sendMessage(MyMessage());
```

`sendMessage` returns a future that yields a `MessageProcessed` when the message has been fully 
processed. There are several subclasses of `MessageProcessed` indicating what sort of processing 
took place

  * `HandledMessage`: indicates that the current leaf state, or one of its ancestor states,
  recognized and handled the message. A transition to a new state may or may not have occurred.
  * `UnhandledMessage`: indicates that the current leaf state, or any of its ancestor states, 
  recognized the message. The message therefore had no effect.
  * `FailedMessage`: indicates that an error occurred while processing the message or during a state
  transition. The current state is unchanged, even if a transition was in progress when the error
  occurred.

Calling code can inspect the result type to handle different cases as necessary:
```dart
var processed = await stateMachine.currentState.sendMessage(MyMessage());
if (processed is HandledMessage) {
  // receivingState is always the current leaf node when the message was sent
  var receivingState = processed.receivingState;
  // handlingState is the state that actually handled the message. 
  // This will be the receivingState, or one of it ancestors. 
  var handlingState = processed.handlingState;
  // transition will not be null if a transition occurred.
  var transition = processed.transition
}
```

## Event streams
`TreeStateMachine` provides several event streams that notify observers as messages are processed.

  * `processedMessages` yields an event for every message that is processed by the tree, whether
    or not the message was handled successfully, and whether or not a transition occurred as a
    result of the message.
  * `handledMessages` is a convenience stream that yields an event when only when a message is
    successfully handled. Note that the `HandledMessage` is also emitted on the `processedMessages`
    stream.
  * `transitions` yields an event each time a transition between states occurs.

## Ending a state machine 
A state machine ends when a transition to a final state occurs. Once the final state is entered, any
additional messages sent to the state are ignored, and a different state may never be entered. The
state machine can be considered 'inert' at that point, although it is possible to retrieve state data from the final state, if the state supports it.

## Stopping a state machine

`TreeStateMachine` has a `stop` method, which is alternate way of ending the state machine. This
will transition the state machine to an implicit final state, identified by `StoppedTreeState.key`.
This state is implicitly available in any state tree.

Once the stopped state has been entered, the state machine is ended in the same manner as if a state
transition to a final state was triggered by message processing. Triggering a transition to a final
state can be considered as 'internally' stopping the state machine, and calling the `stop` method
as 'externally' stopping it.

```dart
await stateMachine.stop();
assert(stateMachine.isEnded);
```