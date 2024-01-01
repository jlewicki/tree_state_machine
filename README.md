# tree_state_machine

`tree_state_machine` is a Dart package for defining and executing hierarchical state machines.

## Features
* Hierarchical state trees
* Asynchronous message processing
* Stream based event notifications
* Declarative state definitions with automated generation of state diagrams in DOT format 
* Nested state machines

## Overview
The `tree_state_machine` library provides APIs for both defining a hierarchical tree of states, and creating state 
machines that create and manage an instance of a state tree. The state machine can be used to dispatch messages to the current state for processing, and receiving notifications as state transitions occur.


## Getting Started
The primary API for the working with a tree state machine is provided by the `tree_state_machine` library. A relatively simple API for defining state trees is provided by the `delegate_builders` library, though extension points are 
provided for creating more sophisticated ones.

The typical usage pattern is simular to the following:
```dart
import 'package:tree_state_machine/delegate_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';


// Define state keys that identify the states in the state tree
sealed class States {
   static const state1 = StateKey('state1');
   static const state1 = StateKey('state2');
}

// Define the state tree
var stateTree = StateTree(
   InitialChild(States.state1), 
   children: [
      State(
         States.state1, 
         onMessage: (MessageContext ctx) => ctx.message == 'go'
            ? ctx.goTo(States.state2) 
            : ctx.unhandled(),
      ),
      State(States.state2),
   ],
);


// Create and start a state machine for the state tree
var machine = TreeStateMachine(stateTree);
var currentState = await machine.start();

// Send a message to be processed by the current state, which may potentially
// cause a transition to a different state
await currentState.post('go');

```
The following sections describe these steps in more detail.


## State Trees

### Naming States
Each state in a state tree is uniquely identified by a `StateKey`. These keys are used when defining states, and naming
the destination state when a state transition occurs. For convenience, they are often grouped together into a containing
class. For example:

```dart
sealed class States {
  static const unauthenticated = StateKey('unauthenticated');
  static const authenticated = StateKey('authenticated');
  // Use DataStateKey to identify a data state with an associated state data type
  static const login = DataStateKey<LoginData>('login');
  // ... 
}
```

The `StateTree` class represents a template for a state tree, and defines the states in the tree, and their hierarchical
relationship. There are several factories available to create a `StateTree`, but the simplest lists the available child states (which themselves may have children), and names the state that will initially be active when the state machine starts.

```dart
StateTree(
   InitialChild(States.unauthenticated), 
   children: [
      // States go here
   ],
);
```

### Defining States
States are declared using the `State` or `DataState` classes. These are created with a `StateKey` that identifies the state, and callbacks that will be used to define how the state behaves.  For example, an `onMessage` callback can 
be provided to specify the message handling behavior of the state. 

```dart
State(
   States.unauthenticated, 
   onMessage: (MessageContext ctx) {
      // Add message handling logic here
      return ctx.unhandled();
   },
);
```

See [Message Handlers](#Message-Handlers) for more details on writing message handlers.

#### Child States
A state can be created with a collection of child states using the `State.composite` factory, so that the state becomes
the parent of the the child states. If a child state is active, but does not handle a message, the parent state will 
have an opportunity to handle it.  

If a state has children, the state must define which of its child states must be entered when the parent is entered 
using `InitialChild`.

```dart
State.composite(
   States.unauthenticated,
   InitialChild(States.splash),
   // Add callbacks to define how the unauthenticated state behaves
   children: [
     // Add callbacks to define how the splash state behaves
     State(States.splash),
   ] 
);
```

#### Data States
States often require additional data to model their behavior. For example, a 'counting' state might need an integer 
value to store the number of times an event occured. The data value(s) needed by a state are collectively referred to as
state data (or more formally, extended state variables).  
  
A data state can be defined using the `dataState` method, providing the type of state data as a type parameter. An 
`InitialData` must be provided, indicating how to create the initial value of the state data when the state is entered.
Also note that a `DataStateKey`, not a `StateKey`, must be used to identify a data state.

```dart
class LoginData {
   String username = '';
   String password = '';
   String errorMessage = '';
}
sealed class States {
  // Data states are identified by DataStateKeys 
  static const login = DataStateKey<LoginData>('login');
}

DataState(
   States.login,
   InitialData(() => LoginData()),
   onMessage: (MessageContext ctx) {
      var loginData = ctx.dataValue(States.login);
      return ctx.unhandled();
   }
)
```
See [Reading and writing state data](#Reading-and-writing-state-data) to learn how to read and write state data when 
handling a message with a data state.


#### Final States
States may be delared as final states. Once a final state has been entered, no further message processing or state 
transitions will occur, and the state tree is considered ended, or complete. Note that a final state is always 
considered a child of the root state, and may not have any child states.

```dart
State.finalState(
   States.lockedOut,
   // Optional onEnter callback may be provided. onMessage and onExit are not available for final 
   // states.
   onEnter: (TransitionContext ctx) {
      // Add onEnter logic here
   }
);
``` 

#### Machine States
Existing state trees or state machines can be composed with a state tree builder as a machine state. A machine state
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
   InitialMachine.fromTree((transCtx) => nestedTreeBuilder()),
   (b) {
      // When the nested machine completes, go to otherState
      b.onMachineDone((b) => b.goTo(otherState));
   }
);
```

### Message Handlers
The way a state responds to a message is defined by the `MessageHandler` function for the state. A message handler is 
provided a `MessageContext` describing the message, and must return a `MessageResult` describing how the state responds
to the message. 

```dart
typedef MessageHandler = FutureOr<MessageResult> Function(MessageContext ctx);
```

Methods on the provided `MessageContext` can be used to create the desired message result. For example, `goTo()`, 
`unhandled()`, or `stay()` 

Because a message handler returns a `FutureOr`, the handler implementation may be asynchronous if desired.  

A message handler is provided with the `onMessage` callback when creating the state:

```dart
class GoToLogin { }
enum Messages { goToRegister }

State(
   States.unauthenticated,
   onMessage: (MessageContext ctx) {
      return switch(ctx.message) {
         // When this state receives a message of type GoToLogin, go to the login 
         // state
         GoToLogin() => ctx.goTo(States.login),
         // When this state receives a goToRegister message value, go to the 
         // registration state
         Messages.goToRegister => mhb.goTo(States.registration),
         // Otherwise, the message is unhandled. An ancestor state can handle it instead.
         _ => ctx.unhandled()
      }; 
   },
);
```


#### Reading and writing state data
A data state can access its associated state data. Additionally, any state can access the state data of an ancestor 
data state. This data can be requested in several ways, but often `MessageContext.updateData` is used to read and update
state data when handling a message.

```dart
State(
   States.credentialsRegistration, 
   onMessageL (ctx) {
      if (ctx.message case SubmitCredentials(email: var email, password: var password))
   b.onMessage<SubmitCredentials>((b) {
      b.goTo(States.demographicsRegistration,
         // Update the RegisterData state data owned by the parent 
         // Registration state. The callback is provided a 
         // MessageHandlerContext, which gives access to the 
         // SubmitCredentials message being handled, and the current 
         // state data value. The callback returns the new state data value.  
         action: b.act.updateData<RegisterData>((ctx) => ctx.data
            ..email = ctx.message.email
            ..password = ctx.message.password));
   });
}, parent: States.registration);
```

### Transition Handlers
A state can receive notifications when it is entered or exited. These notifications are calls to `TransitionHandler`
functions, and the handlers are passed a `TransitionContext` describing the transition that is occurring.
```dart
typedef TransitionHandler = FutureOr<void> Function(TransitionContext ctx);
```

Because a transition handler returns a `FutureOr`, the handler implementation may be asynchronous if desired.  

```dart
treeBuilder.state(States.authenticating, (b) {
   b.onEnter((b) {
      // When this state is entered, perform a login operation, and post 
      // the result of the login as a message for future processing. 
      b.post<AuthFuture>(
          getMessage: (transCtx) => _doLogin(transCtx.payload as SubmitCredentials));
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
      b.enterChannel(authenticatingChannel, (ctx) => ctx.message);
    });
  }, parent: States.login);

treeBuilder.state(States.authenticating, (b) {
    // onEnterFromChannel is similar to onEnter, but but enforces that a 
    // SubmitCredentials was provided.
    b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
      // The builder argument provides access to the SubmitCredentials, in this
      // case as as argument to the getMessage function 
      b.post<AuthFuture>(getMessage: (ctx) => _login(ctx.context, authService));
    });
 }, parent: States.login)
```


## State Machines
### Creating a state machine

Once a state tree has been defined, a state machine can be created.
```dart
var treeBuilder = defineStateTree();
var stateMachine = TreeStateMachine(treeBuilder);
```

### Starting a state machine
Before messages can be sent to the state machine for processing, it has be started. The `start` method returns a future 
that yields a `CurrentState` that serves as a proxy to the current state after the machine has fully started.
```dart
var currentState = await stateMachine.start();
```

### Sending messages
Once a state machine has started, a message may be dispatched to the current leaf state using the `post` method of 
`CurrentState`. This returns a future that completes when the message has been processed and any resulting transition 
has completed.
```dart
var message = SubmitCredentials(username: 'foo', password: 'bar');
var messageResult = await currentState.post(message);
```

### State machine streams
In addition to inspecting the results of `post` to learn about how a message was processed, it is also possible to 
subscribe to several stream properties of TreeStateMachine:

* `processedMessages` yields an event for every message that is processed by the tree, whether or not the message was 
handled successfully, and whether or not a transition occurred as a result of the message.
* `handledMessages` is a convenience stream that yield an event when only when a message is successfully handled. Note 
that the HandledMessage event is also emitted on the processedMessages stream.
* `transitions` yields an event each time a transition between states occurs.

### Ending a state machine
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

### State machine logging
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