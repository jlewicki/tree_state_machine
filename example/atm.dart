import 'dart:async';
import 'package:tree_state_machine/tree_state_machine.dart';

// See https://www.uml-diagrams.org/bank-atm-uml-state-machine-diagram-example.html?context=stm-examples
// for a description of this state machine

enum Messages {
  turnOff,
  turnOn,
  cardInserted,
  cancel,
  service,
}

class RootState extends EmptyTreeState {}

class OffState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.message == Messages.turnOn
        ? context.goTo(StateKey.forState<SelfTestState>())
        : context.unhandled();
  }
}

class SelfTestState extends TreeState {
  static final testPassedMessage = Object();
  static final testFailedMessage = Object();
  Future<bool> _performSelfTest() async {
    return true;
  }

  @override
  FutureOr<void> onEnter(TransitionContext context) async {
    // Perform self test
    final testPassed = await _performSelfTest();
    if (testPassed) {
      context.post(testPassedMessage);
    }
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message == testPassedMessage) {
      return context.goTo(StateKey.forState<IdleState>());
    } else if (context.message == testFailedMessage) {
      return context.goTo(StateKey.forState<OutOfServiceState>());
    }
    return context.unhandled();
  }
}

class IdleState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message == Messages.cardInserted) {
      return context.goTo(StateKey.forState<ServingCustomerState>());
    }
    return context.unhandled();
  }
}

class MaintenanceState extends EmptyTreeState {}

class OutOfServiceState extends EmptyTreeState {}

class ServingCustomerState extends EmptyTreeState {}

class CustomerAuthenticationState extends EmptyTreeState {}

class SelectingTransactionState extends EmptyTreeState {}

class TransactionState extends EmptyTreeState {}

final atmTree = rootBuilder(
  createState: (_) => RootState(),
  initialChild: (_) => StateKey.forState<OffState>(),
  children: [
    leafBuilder(createState: (_) => OffState()),
    leafBuilder(createState: (_) => SelfTestState()),
    leafBuilder(createState: (_) => IdleState()),
    leafBuilder(createState: (_) => MaintenanceState()),
    leafBuilder(createState: (_) => OutOfServiceState()),
    interiorBuilder(
      createState: (_) => ServingCustomerState(),
      initialChild: (_) => StateKey.forState<CustomerAuthenticationState>(),
      children: [
        leafBuilder(createState: (_) => CustomerAuthenticationState()),
        leafBuilder(createState: (_) => SelectingTransactionState()),
        leafBuilder(createState: (_) => TransactionState()),
      ],
    )
  ],
);
