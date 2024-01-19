A state can receive notifications when it is entered or exited. These notifications are calls to 
`TransitionHandler` functions defined by the state, and the handlers are passed a 
`TransitionContext` describing the transition that is occurring.

```dart
typedef TransitionHandler = FutureOr<void> Function(TransitionContext ctx);
```

The `TransitionContext` provides information about the transition, including the full state path of 
the transition (exiting states followed by entering states), and a `data` method providing access
to state data of the handling state (or its ancestors).

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

## Redirects
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
   onEnter: (TransitionContext transCtx) {    
      var token = getAccessToken();
      if (token == null) {
         transCtx.redirectTo(States.unauthenticated);
      }
   },
);
```

An additonal subtlety can occur when creating intial state data for a data state, when the data 
requires additional contextual information during creation. Because the initial data will be 
created before the `onEnter` handler is called, it may be necessary to call `redirectTo` at the 
time the state data is initialized. For example:

```dart
DataState<AuthenticatedUser>(
   States.authenticated, 
   InitialData.run((TransitionContext transCtx) {    
      var token = getAccessToken();
      if (token == null) {
         ctx.redirectTo(States.unauthenticated);
         // It is permissible to return null, but only when redirectTo is 
         // also called
         return null;
      }
      return AuthenticatedUser.fromToken(token);
   },
);
```

