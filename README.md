# tree_state_machine

`tree_state_machine` is a Dart package for defining and executing hierarchical state machines.

## Features
* Hierarchical state trees
* Asynchronous message processing
* Stream based event notifications
* Declarative state definitions with automated generation of state diagrams in DOT format 
* Nested state machines

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
A state can be defined as a child of another state by specifying `parent` when the state is declared. If a state does 
not handle a message, the parent state will have an opportunity to handle it.  

Once a state has 
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
  
A data state can be defined using the `dataState` method, providing the type of state data as a type parameter. An 
`InitialData` must be provided, indicating how to create the initial value of the state data when the state is entered. 
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
### Final States
States may be delared as final states. Once a final state has been entered, no further message processing or state 
transitions will occur, and the state tree is considered ended, or complete. Note that a final state is always 
considered a child of the root state, and may not have any child states.
```dart
treeBuilder.finalState(States.lockedOut, (stateBuilder) {
   // Use state builder to define entry behavior for the state
});
``` 

### Machine States
Existing state tree builders or machines can be composed with a state tree builder as a machine state. A machine state
is a leaf state, and when it is entered a nested state machine will be started. The machine state will forward any 
messages to the nested state machine, and will remain the current state until the nested state machine reaches a final 
state. When it does so, the machine state will invoke a callback to determine the next state to transition to.
```dart

StateTreeBuilder nestedTreeBuilder() {
   var treeBuilder = new StateTreeBuilder();
   // ...define a state tree
   return treeBuilder;
}

final nestedMachineState = StateKey('nestedMachine');
final otherState = StateKey('otherState');

treeBuilder.machineState(
   nestedMachineState, 
   // A nested state machine will be created from this state tree
   InitialMachine.fromTree((transCtx) => nestedTreeBuilder(),
   // When the nested machine completes, go to otherState
   (CurrentState finalState) => otherState),
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
Sometimes when a data state is entered, it requires some contexual information in order to initialize its state date. 
This information typically needs to be provided by the state that initiates the state transition, as the `payload` 
argument of `goTo`. The `Channel<P>` type provides a contract indicating that in order to enter a state, a value of 
type `P` must be provided.
```dart
// In order to enter the authenticating state, a SubmitCredentials value is 
// required.  
final authenticatingChannel = Channel<SubmitCredentials>(States.authenticating);

treeBuilder.state(States.loginEntry, (b) {
    b.onMessage<SubmitCredentials>((b) {
      // enterChannel is similar to goTo, but enforces that a SubmitCredentials
      // value is provided.
      b.enterChannel(authenticatingChannel, (_, msg) => msg);
    });
  }, parent: States.login);

treeBuilder.state(States.authenticating, (b) {
    // onEnterFromChannel is similar to onEnter, but but enforces that a 
    // SubmitCredentials was provided.
    b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
      // The builder argument provides access to the SubmitCredentials, in this
      // case as as argument to the getMessage function 
      b.post<AuthFuture>(getMessage: (_, creds) => _login(creds, authService));
    });
 }, parent: States.login)
```

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

## Sending messages
Once a state machine has started, a message may be dispatched to the current leaf state using the `post` method of 
`CurrentState`. This returns a future that completes when the message has been processed and any resulting transition 
has completed.
```dart
var message = SubmitCredentials(username: 'foo', password: 'bar');
var messageResult = await currentState.post(message);
```

## State machine streams
In addition to inspecting the results of `post` to learn about how a message was processed, it is also possible to 
subscribe to several stream properties of TreeStateMachine:

* `processedMessages` yields an event for every message that is processed by the tree, whether or not the message was 
handled successfully, and whether or not a transition occurred as a result of the message.
* `handledMessages` is a convenience stream that yield an event when only when a message is successfully handled. Note 
that the HandledMessage event is also emitted on the processedMessages stream.
* `transitions` yields an event each time a transition between states occurs.

## Ending a state machine
A state machine can end in two ways.
* When processing a message, if the state machine transitions to a final state, then no other message processing or 
state transitions will occur, and the state machine has ended. This is called an 'internal stop'.
* Calling `stop` on the state machine will transition the machine to an implicit final state, identified by 
`stoppedStateKey`. This state will always be available, and does not need to be added when defining a state tree. This
is called an 'external stop'.
   ```dart
   await stateMachine.stop();
   // done will be true after stopping.
   var done = stateMachine.isDone;
   ```

## State machine logging
The `tree_state_machine` packages logs diagnostic messages using the Dart SDK `logging` package. An application can 
enable `logging` output to view the messages. If hierarchical logging is enabled, all logging is peformed under a parent
logger named `tree_state_machine`.
```dart
hierarchicalLoggingEnabled = true;
Logger('tree_state_machine').level = Level.ALL;
Logger.root.onRecord.listen((record) {
   print('${record.level.name}: ${record.time}: ${record.message}');
});
```