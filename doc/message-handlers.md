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

Provide an `onMessage` callback when defining a state to specify the message handler. If `null`, 
the state will simply forward all messages it recieves to its parent.  

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


## Reading and writing state data
State data can be accessed in a message handler using the `MessageContext.data` method. A data state
can access its associated state data, and any state can access the state data of an ancestor data 
state. Note that only state data for *active* states can be retrieved, otherwise an error is thrown.

State data is stored in a `DataValue<D>` instance. A `DataValue` provides access to the current 
state data value with the `value` property. 

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