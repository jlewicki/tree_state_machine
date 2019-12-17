# Tree State Machine

## Getting Started
The primary API for the working with the state machine is provided by the `tree_state_machine` library. The API for defining state trees is provided by `tree_builders` library.  

Depending on how your application is structured, you will need to import one or both of these libraries:

```dart
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
```

## Defining state trees

The `tree_builders` library defines types that let you construct the tree of states that models your application domain.  In general, there is a class for each type of node in the tree, and you build the tree starting from the root, similar to the way you build a widget tree in Flutter.

For example, here is the definition of a state tree that contains each type of node (`root`, `interior`, `leaf`, and `final`):

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
   finalStates: [
     Final(createState: (key) => MyFinalState()),
   ],
 );
 ```

 For each node, you have to provide a `createState` function that creates the `TreeState` defining the message handling behavior of the node. Additionally, for nodes that can have child nodes (`Root` and `Interior`), you will have to provide definitions of the child nodes, and an `initialChild` function that will select the child state to enter when the state is entered.

 ### Identifying states
 
 Each state in the tree is uniquely identified by a `StateKey`. This key can be optionally assigned when defining the node for the state. If left unassigned a key will automaically be created, using the type name of the `TreeState` subclass returned by the `createState` function.  

 An error is thrown if duplicate keys are found while building the state tree. Therefore, if keys are left unassigned while defining the tree, a different `TreeState` subclass must be used for each node in the tree with an unassigned key to ensure uniqueness.

 ## Creating a state machine

 To create a state machine you simply pass the definition of your state tree to the constructor.  For example:

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

 Before messages can be sent to the state machine for processing, it has be started.  The `start` method returns a `Future` that will complete when the machine has fully started.

 When the machine is started, the machine will determine a path of nodes, starting at the root and ending at a leaf node, by recursively calling the `initialChild` function at each level of the tree until a leaf node is reached. This path of nodes is called the initial path, and the machine will call `onEnter` for each state along this path.

 When all the states along the path have been entered, the state of the leaf node at the end of the path becomes the current state of the state machine, and messages may be sent to this state for processing.

 For example:
 ```dart
 var stateMachine = TreeStateMachine(myTreeBuilder());
 // stateMachine.currentState is null here
 await stateMachine.start()
 // stateMachine.currentState is not null anymore
 var currentStateKey = stateMachine.currentState.key; 
 ```

 Note that `start` accepts an optional `StateKey` that indicates an initial current state. The state machine will use the path from the root to the node with this key, instead of callling `initialChild`, when determining which states to enter when starting.

## Message processing

Once the state machine has been started, messages may be sent to the current state for processing by calling `sendMessage`.

This method returns a future that yields a `MessageProcessed` when processing is complete. There are several subclasses of `MessageProcessed` indicating what sort of processing took place:

  * `HandledMessage`: indicates that the current leaf state, or one of its ancestor states, recogized and handled the message. A transition to a new state may or may not have occurred. 
  * `UnhandledMessage`: indicates that the current leaf state, or any of its ancestor states, recognized the message. The message therefore had no effect.
  * `FailedMessage`: indicates that an error occurred while processing the message or during a state transition.  The current state is unchanged, even if a transition was in progress when the error occurred.

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


## Ending a state machine 

## Stopping a state machine