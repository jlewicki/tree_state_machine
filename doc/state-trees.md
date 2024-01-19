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

## Naming States
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

## Defining States
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

### Child States
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

### Data States
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
      // Use the MessageContext.data method to retrieve the current state 
      // data for a data state.   
      var loginData = ctx.data(States.login).value;
      return ctx.unhandled();
   }
);
```

The previous example illustates creating inital data when the initial value is known at design time.
Occasionly it may be necessary to defer creation until runtime, when the data state is being 
entered. For example, the data may need to incorporate values obtained from the `payload` of the
`TransitionContext`.  To handle this, use the `InitialData.run` factory:

```dart
DataState(
   States.login,
   InitialData.run((TransitionContext transCtx) {
      var userInfo = transCtx.payload as SavedUserInfo;
      return LoginData()..email = userInfo.email;
   }),
);
```


See [Reading and writing state data](#Reading-and-writing-state-data) to learn how to read and write
state data when handling a message with a data state.


### Final States
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

### Machine States
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

