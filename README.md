# tree_state_machine

`tree_state_machine` is a Dart package for defining and executing hierarchical state machines.

## Features
* Hierarchical state trees
* Asynchronous message processing
* Stream based event notifications
* Declarative state definitions with automated generation of state diagrams in DOT format 
* Nested state machines

## Overview
The `tree_state_machine` package provides APIs for defining a hierarchical tree of states, and 
creating state machines that can manage an instance of a state tree. The state machine can be used 
to dispatch messages to the current state for processing, and receive notifications as state 
transitions occur.

Refer to [UML state machines](https://en.wikipedia.org/wiki/UML_state_machine) for further 
conceptual background on hierarchical state machines. 

## Getting Started
The primary API for the working with a tree state machine is provided by the `tree_state_machine` 
library. A relatively simple API for defining state trees is provided by the `delegate_builders` 
library, though extension points are provided in the `build` library for creating more sophisticated
ones.

A typical usage looks like the following:
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
   childStates: [
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
Each state in a state tree is uniquely identified by a `StateKey`. These keys are used when defining
states, and naming the destination state when a state transition occurs. For convenience, they are 
often grouped together into a containing class. For example:

```dart
sealed class States {
  static const unauthenticated = StateKey('unauthenticated');
  static const authenticated = StateKey('authenticated');
  // Use DataStateKey to identify a data state with an associated state data type
  static const login = DataStateKey<LoginData>('login');
  // ... 
}
```

The `StateTree` class represents a template for a state tree, defining the states in the tree and 
their hierarchical relationship. There are several factories available to create a `StateTree`, but
the simplest lists the available child states (which themselves may have children), and names the 
state that will initially be active when the state machine starts.

```dart
StateTree(
   InitialChild(States.unauthenticated), 
   childStates: [
      // States go here
   ],
);
```

### Defining States
States are declared using the `State` or `DataState` classes. These are created with a `StateKey` 
that identifies the state, and callbacks that will be used to define how the state behaves.  For 
example, an `onMessage` callback can be provided to specify the message handling behavior of the 
state. 

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
A state can be created with a collection of child states using the `State.composite` factory, so 
that the state becomes the parent of the the child states. If a child state is active, but does not
handle a message, the parent state will have an opportunity to handle it.  

If a state has children, it must specify which of its child states to be enter when the parent is 
entered using `InitialChild`.

```dart
State.composite(
   States.unauthenticated,
   InitialChild(States.splash),
   children: [
      State(States.splash),
   ] 
);
```

#### Data States
States often require additional data to model their behavior. For example, a 'counting' state might 
need an integer value to store the number of times an event occured. The data value(s) needed by a 
state are collectively referred to as state data (or more formally, extended state variables).  
  
A data state can be defined using the `DataState` class, providing the type of state data as a type 
parameter. An `InitialData` must be provided, indicating how to create the initial value of the 
state data when the state is entered. Also note that a `DataStateKey`, not a `StateKey`, must be 
used to identify a data state.

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
      // Usde the MessageContext.data method to retrieve the current state 
      // data for a data state.   
      var loginData = ctx.data(States.login).value;
      return ctx.unhandled();
   }
)
```

See [Reading and writing state data](#Reading-and-writing-state-data) to learn how to read and write
state data when handling a message with a data state.


#### Final States
States may be delared as final states. Once a final state has been entered, no further message 
processing or state transitions will occur, and the state tree is considered ended, or complete. 
Note that a final state is always considered a child of the root state, and may not have any child 
states.

```dart
StateTree(
   finalStates: [
      FinalState(
         States.lockedOut,
         // An optional onEnter callback may be provided. onMessage and onExit are not
         // available for final states.
         onEnter: (TransitionContext ctx) {
            // Add onEnter logic here
         }
      ),
   ],
);
``` 

#### Machine States
Existing state trees or state machines can be composed with a second 'outer' state tree using a 
machine state. A machine state is a leaf state, and when it is entered an inner state machine will 
be started. The machine state will forward any messages from the outer state machine to the inner, 
and will remain the current state of the outer state machine until the inner reaches a final state. 
When it does so, the machine state will invoke a callback to determine the next state for the outer 
state machine to transition to.

```dart

StateTree innerStateTree() {
   return StateTree(
      // ...define a state tree
   );
}

// Machine states need to be identified by MachineStateKey
final aMachineState = MachineStateKey('machineState');
final otherState = StateKey('otherState');

MachineState(
   aMachineState, 
   // A nested state machine will be created from the state tree
   InitialMachine.fromStateTree((TransactionContext ctx) => innerStateTree()),
   onMachineDone: (MessageContext ctx, CurrentState currentInnerState) =>
      // The inner state machine has completed, so determine the next state of the outer 
      // state machine. 
      ctx.goTo(otherState),
);
```

### Message Handlers
The way a state responds to a message is defined by the `MessageHandler` function for the state. A 
message handler is provided a `MessageContext` describing the message, and must return a 
`MessageResult` describing how the state responds to the message. 

```dart
typedef MessageHandler = FutureOr<MessageResult> Function(MessageContext ctx);
```

Methods on the provided `MessageContext` can be used to create the desired message result. For 
example, `goTo()`, `unhandled()`, or `stay()` 

Because a message handler returns a `FutureOr`, the handler implementation may be asynchronous if 
desired.  

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
A data state can access its associated state data. Additionally, any state can access the state data
of an ancestor data state. 

State data is stored in a `DataValue<D>` instance. A `DataValue` provides access to the current 
state data value with the `value` property. The `DataValue` for a data state can be requested using
the `MessageContext.data` and `TransitionContext.data` methods.

A `DataValue` is also a `Stream`, and therefore can be used to observe changes to the state data 
over time.  This is not typically used in a message handler, but `DataValue`s are also accessible
from a `TreeStateMachine`, and the change notifications can prove useful at the application level.  

The `DataValue.update` method can be use to update the current value, which will cause the 
associated `Stream` to emit a new value.

```dart
State(
   States.credentialsRegistration, 
   onMessage: (ctx) {
      if (ctx.message case SubmitCredentials(email: var email, password: var password)) {
         // Update the RegisterData state data owned by an ancestor Register state. 
         ctx.data(States.register).update((RegisterData data) => data
            ..email = email
            ..password = password);
         return ctx.goTo(States.demographicsRegistration);
      } 
      return ctx.unhandled();
   },
);
```

### Transition Handlers
A state can receive notifications when it is entered or exited. These notifications are calls to 
`TransitionHandler` functions, and the handlers are passed a `TransitionContext` describing the 
transition that is occurring.
```dart
typedef TransitionHandler = FutureOr<void> Function(TransitionContext ctx);
```

The `TransitionContext` provides information about the transition, including the full state path of 
the transition (exiting states followed by entering states).

Because a transition handler returns a `FutureOr`, the handler implementation may be asynchronous if
desired.  

```dart
State(
   States.authenticating, 
   onEnter: (TransitionContext ctx) {    
      // When this state is entered, perform a login operation, and post 
      // the result of the login as a message for future processing.
      ctx.post(_doLogin(transCtx.payload as SubmitCredentials));
   },
);
```
#### Redirects
A state may have certain preconditions that need to be satisfied in order to enter the state 
successfully. For example, if a state represents the presence of an authenticated user, an access 
or identity token may be required to identify the user. If for some reason the token cannot be 
obtained, it is not meaningful to enter this state.

To handle this case, an entry transition handler can call `TransitionContext.redirectTo` on order
to redirect the transition to a different destination. So for example when a auth token cannot be
obtained, the handler for the authenticated state might redirect to a state representing an 
anonymous user. 

```dart
State(
   States.authenticated, 
   onEnter: (TransitionContext ctx) {    
      var token = getAccessToken();
      if (token == null) {
         ctx.redirectTo(States.unauthenticated);
      }
   },
);
```

## State Machines
### Creating a state machine

Once a state tree has been defined, a state machine can be created.
```dart
var stateTree = defineStateTree();
var stateMachine = TreeStateMachine(stateTree);
```

### Starting a state machine
Before messages can be sent to the state machine for processing, it has be started. The `start` 
method returns a future that yields a `CurrentState` that serves as a proxy to the current state 
after the machine has fully started.
```dart
var currentState = await stateMachine.start();
```

### Sending messages
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


### State machine streams
In addition to inspecting the results of `post` to learn about how a message was processed, it is 
also possible to  subscribe to several stream properties of `TreeStateMachine`:

* `processedMessages` yields an event for every message that is processed by the tree, whether or 
not the message was handled successfully, and whether or not a transition occurred as a result of 
the message.
* `handledMessages` is a convenience stream that yield an event when only when a message is 
successfully handled. Note that the HandledMessage event is also emitted on the processedMessages 
stream.
* `transitions` yields an event each time a transition between states occurs.

### Ending a state machine
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

### State machine logging
The `tree_state_machine` packages logs diagnostic messages using the Dart SDK `logging` package. An
application can enable `logging` output to view the messages. If hierarchical logging is enabled, 
all logging is peformed under a parent logger named `tree_state_machine`.
```dart
hierarchicalLoggingEnabled = true;
Logger('tree_state_machine').level = Level.ALL;
Logger.root.onRecord.listen((record) {
   print('${record.level.name}: ${record.time}: ${record.message}');
});
```