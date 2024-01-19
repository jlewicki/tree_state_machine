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