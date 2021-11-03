# tree_state_machine

`tree_state_machine` is a Dart package for defining and executing hierarchical state machines.

## Features

TODO: List what your package can do. Maybe include images, gifs, or videos.

## Getting Started
The primary API for the working with a tree state machine is provided by the `tree_state_machine` library. The API for 
defining state trees is provided by `tree_builders` library. Depending on how your application is structured, you will 
need to import one or both of these libraries.
```dart
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
```

## Naming States
Each state in a state tree is uniquely identified by a `StateKey`. These keys are used when defining states, and naming
the destination state when a state transition occurs. For convenience, they are often grouped together into a containing
class.
```dart
class States {
  static const unauthenticated = StateKey('unauthenticated');
  static const authenticated = StateKey('authenticated');
  ... 
}
```

## Defining a state tree
`StateTreeBuilder` is used to to declare the states in a state tree. There are several factories available to create a
a `StateTreeBuilder`, but the simplest names the state that will initially be active when the state machine starts.

```dart
var treeBuilder = StateTreeBuilder(initialState: States.unauthenticated);
```

## Declaring States
States are declared using the `state` method, passing a `StateKey` to identify the state, and a callback that will be 
used to define how the state behaves.
```dart
treeBuilder.state(States.unauthenticated, (stateBuilder) {
   // Use state builder to define how the unauthenticated state behaves
}, initialChild: InitialChild(States.splash));
```
See [Message Handlers](#Message-Handlers) to see how to use the state builder.

### Child States
A state can be defined as a child of another state by specifying `parent` when the state is declared. Once a state has 
been assigned a parent, the parent state must define which of its child states must be entered when the parent is 
entered using `initialChild`.
```dart
treeBuilder.state(States.splash, (stateBuilder) {
   // Use state builder to define how the splash state behaves
}, parent: States.unauthenticated);
```
If a state declaration does not specify `initialChild`, that state is considered a leaf state in the state tree. 

### Data States
States often require additional data to model their behavior. For example, a 'counting' state might need an integer 
value to store the number of times an event occured. The data value(s) needed by a state are collectively referred to as
state data (or more formally, extended state variables).  
  
A data state can be defined using the `dataState` method, providing the type of state data as a type parameter. An `InitialData` must be provided, indicating how to create the initial value of the state data when the state is entered. 
```dart
class LoginData {
   String username = '';
   String password = '';
   String errorMessage = '';
}

treeBuilder.dataState<LoginData>(
   States.login,
   InitialData(() => LoginData()),
   (stateBuilder) {
      // Use state builder to define how the splash state behaves
   },
   parent: States.unauthenticated,
   initialChild: InitialChild(States.loginEntry),
);
```

## Message Handlers
The way a state responds to a message is defined by the `MessageHandler` function for the state. A message handler is 
provided a `MessageContext` describing the message, and must return a `MessageResult` describing how the state responds to 
the message.
```dart
typedef MessageHandler = FutureOr<MessageResult> Function(MessageContext ctx);
```

Message handlers are typically not defined directly. Instead `StateBuilder`, `MessageHandlerBuilder` and associated 
types can be used to specify the handler in a declarative fashion. `MessageHandlerBuilder` has several methods, such as
`goTo`, that correspond to different types of `MessageResult`. 

Note that any object can be a message, and message handlers can be declared by message type or message value. 
```dart
class GoToLogin { }
enum Messages { goToRegister }

treeBuilder.state(States.unauthenticated, (sb) {
  // When this state receives a message of type GoToLogin, go to the login 
  // state
  sb.onMessage<GoToLogin>((mhb) => mhb.goTo(States.login));
  // When this state receives a goToRegister message value, go to the 
  // registration state
  sb.onMessageValue(Messages.goToRegister, (mhb) => mhb.goTo(States.registration));
}, initialChild: InitialChild(States.splash));
```
### Message actions
Often addition actions need to be taken when a state handles a message, in addition to transitioning to a different 
state. These actions can be defined with `MessageActionBuilder` and associated types, and passed to the `action` 
parameter of `goTo` and similar methods. These actions are run before `MessageResult` returned by the message handler
is processed by the state machine. 

### Reading and writing state data
A data state can access its associated state data. Additionally, any state can access the state data of an ancestor 
data state. This data can be requested in several ways, but often `updateData` is used to read and update state data 
when handling a message.

```dart
treeBuilder.state(States.credentialsRegistration, (b) {
   b.onMessage<SubmitCredentials>((b) {
      b.goTo(States.demographicsRegistration,
         // Update the RegisterData state data owned by the parent 
         // Registration state. The callback is provided the message 
         // context, the SubmitCredentials message being handled, and 
         // the current state data value. The callback returns the new
         // state data value.  
         action: b.act.updateData<RegisterData>((msgCtx, msg, data) => data
            ..email = msg.email
            ..password = msg.password));
   });
}, parent: States.registration);
```

## Transition Handlers
A state can receive notifications when it is entered or exited. These notifications are calls to `TransitionHandler`
functions, and the handlers are passed a `TransitionContext` describing the transition that is occurring.
```dart
typedef TransitionHandler = FutureOr<void> Function(TransitionContext ctx);
```

Similar to message handlers, transition handlers are typically not defined directly. `StateBuilder` has methods such as 
`onEnter` and `onExit` for declaring how these handlers should behave. 
```dart
treeBuilder.state(States.authenticating, (b) {
   b.onEnter((b) {
      // When this state is entered, perform a login operation, and post 
      // the result of the login as a message for future processing. 
      b.post<AuthFuture>(
          getValue: (transCtx) => _doLogin(transCtx.payload as SubmitCredentials));
   });
}
```

### Entry channels


## Creating a state machine

Once a state tree has been defined, a state machine can be created.
```dart
var treeBuilder = defineStateTree();
var stateMachine = TreeStateMachine(treeBuilder);
```

## Starting a state machine
Before messages can be sent to the state machine for processing, it has be started. The `start` method returns a future 
that yields a `CurrentState` that serves as a proxy to the current state after the machine has fully started.
```dart
var currentState = await stateMachine.start();
```

When the machine is started, the machine determines determine a path of states, starting at the root and ending at a 
leaf state, by recursively determining the `initialChild` at each level of the tree until a state with no children is
reached. This path of states is called the initial path, and the machine will call `onEnter` for each state along this 
path.

When all the states along the path have been entered, the state at the end of the path becomes the current state of the 
state machine.

## Sending messages
Once a state machine has started, a message may be dispatched to the current leaf state using the `post` method of 
`CurrentState`. This returns a future that completes when the message has been processed and any resulting transition 
has completed.
```dart
var message = SubmitCredentials(username: 'foo', password: 'bar');
var messageResult = await currentState.post(message);
```

## State machine streams
In addition to inspecting the results of sendMessage to learn about how a message was processed, it is also possible to 
subscribe to several stream properties of TreeStateMachine:

* `processedMessages` yields an event for every message that is processed by the tree, whether or not the message was 
handled successfully, and whether or not a transition occurred as a result of the message.
* `handledMessages` is a convenience stream that yield an event when only when a message is successfully handled. Note 
that the HandledMessage event is also emitted on the processedMessages stream.
* `transitions` yields an event each time a transition between states occurs.

## Stopping a state machine
`TreeStateMachine` has a `stop` method, which is alternate way of ending the state machine. This will transition the 
state machine to an implicit final state, identified by `stoppedStateKey`. This state will always be available, and does
not need to be added when defining a state tree. 

Once the stopped state has been entered, the state machine is ended in the same manner as if a state transition to a 
final state was triggered by message processing. You can consider triggering a transition to a final state as 
'internally stopping' the state machine, and calling the stop method as 'externally stopping' it.
```dart
await stateMachine.stop();
// done will be true after stopping.
var done = stateMachine.isDone;
```