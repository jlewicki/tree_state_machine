import 'dart:async';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// https://docs.spring.io/spring-statemachine/docs/1.1.1.RELEASE/reference/htmlsingle/#statemachine-examples-turnstile

enum Messages {
  coin,
  push,
}

class LockedState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.message == Messages.coin
        ? context.goTo(StateKey.forState<UnlockedState>())
        : context.unhandled();
  }
}

class UnlockedState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.message == Messages.push
        ? context.goTo(StateKey.forState<LockedState>())
        : context.unhandled();
  }
}

final turnstileStates = [
  Leaf(createState: (_) => LockedState()),
  Leaf(createState: (_) => UnlockedState()),
];

final stateMachine = TreeStateMachine.forLeaves(
  turnstileStates,
  StateKey.forState<LockedState>(),
);
