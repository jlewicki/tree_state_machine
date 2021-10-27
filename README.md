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
b.state(States.credentialsRegistration, (b) {
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