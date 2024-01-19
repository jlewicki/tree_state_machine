# tree_state_machine

`tree_state_machine` is a Dart package for defining and executing hierarchical state machines.

## Features
* Hierarchical state trees
* Asynchronous message processing
* Stream based event notifications
* Declarative state definitions 
* Nested state machines

## Overview
The `tree_state_machine` package provides APIs for defining a hierarchical tree of states, and 
creating state machines that can manage an instance of a state tree. The state machine can be used 
to dispatch messages to the current state for processing, and receive notifications as state 
transitions occur.

Refer to [UML state machines](https://en.wikipedia.org/wiki/UML_state_machine) for further 
conceptual background on hierarchical state machines. 

## Documentation
See the API documentation for details on the following topics:

- [Getting started](https://pub.dev/documentation/tree_state_machine/latest/topics/Getting%20Started-topic.html)
- [State Trees](https://pub.dev/documentation/tree_state_machine/latest/topics/State%20Trees-topic.html)
- [Message Handlers](https://pub.dev/documentation/tree_state_machine/latest/topics/Message%20Handlers-topic.html)
- [Transition Handlers](https://pub.dev/documentation/tree_state_machine/latest/topics/Transition%20Handlers-topic.html)
- [State Machines](https://pub.dev/documentation/tree_state_machine/latest/topics/State%20Machines-topic.html)


## Further References
* The [`tree_state_router`](https://pub.dev/packages/tree_state_router) package, for declarative 
routing in Flutter apps based on a `TreeStateMachine`.
