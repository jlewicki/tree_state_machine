import 'package:tree_state_machine/tree_state_machine.dart';

enum Messages {
  turnOff,
  turnOn,
  cardInserted,
  cancel,
  service,
}

class RootState extends EmptyTreeState {}

class OffState extends EmptyTreeState {}

class SelfTestState extends EmptyTreeState {}

class IdleState extends EmptyTreeState {}

class MaintenanceState extends EmptyTreeState {}

class OutOfServiceState extends EmptyTreeState {}

class ServingCustomerState extends EmptyTreeState {}

class CustomerAuthenticationState extends EmptyTreeState {}

class SelectingTransactionState extends EmptyTreeState {}

class TransactionState extends EmptyTreeState {}

final atmTree = BuildRoot(
  state: (_) => RootState(),
  initialChild: (_) => StateKey.forState<OffState>(),
  children: [
    BuildLeaf((_) => OffState()),
    BuildLeaf((_) => SelfTestState()),
    BuildLeaf((_) => IdleState()),
    BuildLeaf((_) => MaintenanceState()),
    BuildLeaf((_) => OutOfServiceState()),
    BuildInterior(
      state: (_) => ServingCustomerState(),
      initialChild: (_) => StateKey.forState<CustomerAuthenticationState>(),
      children: [
        BuildLeaf((_) => CustomerAuthenticationState()),
        BuildLeaf((_) => SelectingTransactionState()),
        BuildLeaf((_) => TransactionState()),
      ],
    )
  ],
);
