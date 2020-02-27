# tree_state_machine

`tree_state_machine` is a Dart package that provides a simple and declarative way to define and 
execute a tree state machine.

## Tree State Machines
A tree (hierarchical) state machine is a similar to a traditional finite state machine (FSM), in 
that the state of a system is modeled by a set of discrete states, one of which one is current 
(active) at any given time. The system can transition from one state to another in response to 
messages (typically representing some sort of external event) being processed by the current state.

In a tradtional FSM, each state exists independently, and if a state machine is in a particular 
state, then it cannot simultaneously be in any of the other states. This is sufficient for many 
models, but can lead to duplicated message handling logic. For example, imagine modeling an 
electronics device of some sort. In this model, one would likely define TurnOn and TurnOff messages,
and TurnOff would probably need to be processed by a number of states. If each state handled this 
message, the logic associated with turning off the device might potentially be spread across a 
number of states.

Tree state machines are a way of addressing this issue. The states are arranged into a tree, so that
a state can have zero or more child states. If a state has no child states, we call it a leaf state,
otherwise it's called a composite state. The power of this hierarchical relationship is that states
can delegate message handling to their parent state, allowing one parent state to provide common 
message handling logic for any number of child states (and their children, etc.)

## Getting Started
The primary API for the working with a tree state machine is provided by the `tree_state_machine`
library. The API for defining state trees is provided by `tree_builders` library. Depending on how
your application is structured, you will need to import one or both of these libraries:

```dart
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
```

## Defining states
A state tree is composed of number of states, where a state is effectively defined by how it 
responds to the messages that are sent to the state machine for processing.

In `tree_state_machine`, a state is a subclass of `TreeState`, and each state provides its message
handling behavior by overriding the `onMessage` method:

```dart
class MyState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.message is SomeMessage 
      ? context.goTo(StateKey.forState<OtherState>())
      : context.unhandled();
  }
}
```
A few things to note about this example:
  
  * A `MessageContext` is provided as an argument to `onMessage`. This context provides access to 
  the message to be processed, as a well as a number of methods (such as `goTo`) that produce the `MessageResult`s that can be returned from the method.
  * The return type is `FutureOr<MessageResult>`, which means `onMessage` is free to return a future,
  if its message handling logic is asynchronous in nature. 
  * The `goTo` method, which initiates a state transition, takes a `StateKey` as a parameter to
  indicate which state to  transition to. In this case we are using the type name of the target 
  state to generate a key. See [below](#state-keys) for more details on state keys.
  * `context.unhandled()` is returned when the message is not recognized. The state machine will 
  next call `onMessage` of the parent state to see if it can handle the message.

### Transition handlers
In addition to `onMessage`, `TreeState` provides overridable methods `onEnter` and `onExit`. These 
methods are called when the state is entered or exited as a result of a state transition (or when
the state machine enters its initial state when it is started).

`TreeState` subclasses can override these methods to perform any initialization or cleanup that is 
necessary as the state is entered and exited.

```dart
class MyState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    /// Perform initialization here if necessary
  }

  @override
  FutureOr<void> onExit(TransitionContext context) {
    /// Perform cleanup here if necessary
  }
}
```

### State data and DataTreeState

Sometimes a state cannot be easily modeled by just extending `TreeState` and overriding its methods.
For example, consider a state or set of states that needs to maintain a counter of some sort, 
perhaps the number of times a user has clicked a button. In theory, this could be modeled by a large
number of states such as `Clicked1Times`, `Clicked2Times`, `Clicked2Times`, etc. However this is 
clearly not practical as the number of states grows. Alternatively, this could be modeled by a 
single `Clicking` state that has a `count` field. In `tree_state_machine`, fields such as `count` 
that capture the 'state' of a `TreeState` are referred to as 'state data' (note that these are 
sometimes called 'extended state' or 'extended state variables' in other state machine frameworks).

While a `TreeState` subclass can simply define member fields to represent state data (and this is 
sometimes the most pratical approach), `tree_state_machine` offers additional support for state data
with `DataTreeState<D>` and `DataProvider<D>`, including:
  
  * Change notificaton of updated data values by publishing to an `Observable<D>`
  * Encoding/decoding of data in the active nodes of a state tree. This can be useful for saving and
    reloading state trees across application sessions.

To take advantage of this support:

  * Define a class that represents the additional state data.
  * Define a state by extending `DataTreeState<D>` instead of `TreeState`, where `D` is the data 
  class creatred in the previous step. The subclass can access the data class via the `data` 
  property of `DataTreeState<D>`. 
  * When the state needs to modify the value(s) in the data class, it should do so in a callback
  provided to the `updateData` or `replaceData` methods of `DataTreeState<D>`.

For example:
```dart
class CountingData {
   int count;
}

class CountingState extends DataTreeState<CountingData> {

   @override
   FutureOr<MessageResult> onMessage(MessageContext context) {
     if (context.message is IncrementMessage) {
        updateData((data) {
          data.count += 1; 
        });
        return context.stay();
     } 
     return context.unhandled();
  }
}
```  

## Defining state trees

The `tree_builders` library defines types that let you construct the tree of states that models your
application domain. In general, there is a builder class for each type of node in the tree, and you
build the tree starting from the root, similar to the way you build a widget tree in Flutter.

> Note: States and nodes are sometimes used interchangably, but in fact they are distinct. A
`TreeState` represents message handling behavior, while a node represents the position of a state
within a state tree. Application code typically does not interact directly with the nodes in the 
tree.

For example, here is the definition of a state tree that contains each type of node (`Root`, 
`Interior`, `Leaf`, and `Final`):

```dart
var treeBuilder = Root(
  createState: (key) => MyRootState(),
  initialChild: (transitionContext) => StateKey.forState<MyInteriorState>(),
   children: [
    Interior(
      createState: (key) => MyInteriorState(),
      initialChild: (transitionContext) => StateKey.forState<MyLeafState1>(),
      children: [
        Leaf(createState: (key) => MyLeafState1()),
        Leaf(createState: (key) => MyLeafState2()),
      ]
    ),
    Leaf(createState: (key) => MyLeafState3()),
  ],
  finals: [
    Final(createState: (key) => MyFinalState()),
  ],
);
```

For each node, you have to provide a `createState` function that creates the `TreeState` defining 
the message handling behavior of the node. Additionally, for nodes that can have child nodes 
(`Root` and `Interior`), you will have to provide definitions of the child nodes, and an 
`initialChild` function that will select the child state to enter when the state is entered.

### Data states
If you want to add `DataTreeState<D>` to the state tree, you will need to use the `WithData` 
variants of the builder clases (`LeafWithData`, `InteriorWithData`, and `RootWithData`). 
Additionally, you must provide a function that will create the `DataProvider<D>` associated with
the state:

```dart

// A state data class that supports serialization using the json_serializable package.
@JsonSerializable()
class RegisterData {
  String name;
  int age;
  Map<String, dynamic> toJson() => _$RegisterDataToJson(this);
  static OwnedDataProvider<RegisterData> dataProvider([RegisterData initialValue]) =>
      // Use JSON serialization functions when creating a data provider.
      OwnedDataProvider.json(
        () => initialValue ?? RegisterData(),
        _$RegisterDataToJson,
        _$RegisterDataFromJson,
      );
}

// State class that uses the state data class
class RegistrationState extends DataTreeState<RegisterData> {
   @override
   FutureOr<MessageResult> onMessage(MessageContext context) {
     /// Some registration logic
   }
}

var treeBuilder = Root(
  createState: (key) => MyRootState(),
  initialChild: (transitionContext) => StateKey.forState<RegistrationState>(),
  children: [
    // Add the data state to the state tree.
    InteriorWithData(
      createState: (_) => RegistrationState(),
      createProvider: RegisterData.dataProvider,
      initialChild: (_) => StateKey.forState<RegisterCredentialsState>(),
      children: [
        Leaf(createState: (_) => RegisterCredentialsState()),
        Leaf(createState: (_) => RegisterDemographicsState()),
      ],
    ),
    // ...other states
  ],
);



// 
InteriorWithData(
    createState: (_) => RegistrationState(),
    createProvider: RegisterData.dataProvider,
    initialChild: (_) => StateKey.forState<RegisterCredentialsState>(),
    children: [
      Leaf(createState: (_) => RegisterCredentialsState()),
      Leaf(createState: (_) => RegisterDemographicsState()),
    ],
  ),
```


### <a name="state-keys"></a>Identifying states

Each state in the tree is uniquely identified by a `StateKey`. This key can be optionally assigned 
when defining the node for the state. If left unassigned a key will automatically be created, using
the type name of the `TreeState` subclass returned by the `createState` function. A `StateKey` can 
always be created using `StateKey.named` and assigned explicitly to a node if that is preferred. 

An error is thrown if duplicate keys are found while building the state tree. Therefore, if keys are
left unassigned while defining the tree, in order to ensure uniqueness, a different `TreeState`
subclass must be used for each node in the tree with an unassigned key.

## Creating a state machine

To create a state machine you simply pass the definition of your state tree to the constructor. For
example:

```dart
var treeBuilder = Root(
   createState: (key) => MyRootState(),
   initialChild: (transitionContext) => StateKey.forState<MyLeafState1>(),
   children: [
     Leaf(createState: (key) => MyLeafState1()),
     Leaf(createState: (key) => MyLeafState2()),
   ],
 );
var stateMachine = TreeStateMachine(treeBuilder);
``` 

 ## Starting a state machine

Before messages can be sent to the state machine for processing, it has be started.  The `start` 
method returns a future that will complete when the machine has fully started.

When the machine is started, the machine will determine a path of nodes, starting at the root and
ending at a leaf node, by recursively calling the `initialChild` function at each level of the tree
until a leaf node is reached. This path of nodes is called the initial path, and the machine will 
call `onEnter` for each state along this path.

When all the states along the path have been entered, the state of the leaf node at the end of the
path becomes the current state of the state machine, and messages may be sent to this state for
processing.

For example:
```dart
var stateMachine = TreeStateMachine(myTreeBuilder());
// stateMachine.currentState is null here
await stateMachine.start()
// stateMachine.currentState is not null anymore
var currentStateKey = stateMachine.currentState.key; 
```

Note that `start` accepts an optional `StateKey` that indicates an initial current state. The state
machine will use the path from the root to the node with this key, instead of callling
`initialChild`, when determining which states to enter when starting.

## Message processing

Once the state machine has been started, messages may be sent to the current state for processing by
calling `sendMessage`.

This method returns a future that yields a `MessageProcessed` when processing is complete. There are
several subclasses of `MessageProcessed` indicating what sort of processing took place:

  * `HandledMessage`: indicates that the current leaf state, or one of its ancestor states,
  recogized and handled the message. A transition to a new state may or may not have occurred.
  * `UnhandledMessage`: indicates that the current leaf state, or any of its ancestor states, 
  recognized the message. The message therefore had no effect.
  * `FailedMessage`: indicates that an error occurred while processing the message or during a state
  transition. The current state is unchanged, even if a transition was in progress when the error
  occurred.

  The following example illustrates sending a message and checking the result:

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
### State machine streams

In addition to inspecting the results of `sendMessage` to learn about how a message was processed,
it is also possible to subscribe to several stream properties of `TreeStateMachine`:

  * `processedMessages` yields an event for every message that is processed by the tree, whether
    or not the message was handled successfully, and whether or not a transition occurred as a
    result of the message.
  * `handledMessages` is a convenience stream that yield an event when only when a message is
    successfully handled. Note that the `HandledMessage` is also emitted on the `processedMessages`
    stream.
  * `transitions` yields an event each time a transition between states occurs.


## Ending a state machine 

A state machine is considered to be ended, or finished, when a transition to a final state occurs. A
final state can be included in a state tree definition by adding one or more `Final` nodes to the 
`finals` collection of the `Root`.

When handling a message, a state may transition to a final state in the same way it would to any
other state. However, once the final state is entered, any additional messages sent to the state are
ignored, and a different state may never be entered. The state machine can be considered 'inert' at
that point, although it is possible to retrieve state data from the final state, if the state 
supports it.

```dart
class MyState extends TreeState {
   FutureOr<MessageResult> onMessage(MessageContext context) {
      return context.message is MyStopMessage
         // When the state machine enters MyFinalState, it will be ended.
         : context.goTo(StateKey.state<MyFinalState>()
         ? context.unhandled();
      }
   }
}
```

## Stopping a state machine

`TreeStateMachine` has a `stop` method, which is alternate way of ending the state machine. This
will transition the state machine to an implicit final state, identified by `StoppedTreeState.key`.
This state does not need to be added to the `finals` collection of the `Root`, it will be 
automatically available.

Once the stopped state has been enterd, the state machine is ended in the same manner as if a state
transition to a final state was triggered by message processing. You can consider triggering a 
transition to a final state as 'internally stopping' the state machine, and calling the `stop`
method as 'externally stopping' it.

```dart
await stateMachine.stop();
// ended will be true
var ended = stateMachine.isEnded;
```