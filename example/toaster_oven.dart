import 'dart:async';
import 'package:tree_state_machine/src/helpers.dart';
import 'package:tree_state_machine/src/builders/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// https://en.wikipedia.org/wiki/UML_state_machine

///////////////////////////////////////////////////////////////////////////////////////////////////
///
/// Messages
///
abstract class Message {}

class BakeMessage extends Message {}

class ToastMessage extends Message {}

class SetTempMessage extends Message {
  final int temp;
  SetTempMessage(this.temp);
}

class SetToastingColorMessage extends Message {
  final String color;
  SetToastingColorMessage(this.color);
}

///////////////////////////////////////////////////////////////////////////////////////////////////
///
/// States
///

class RootState extends EmptyTreeState {}

class HeatingState extends TreeState {
  final HeatingElement heater;
  HeatingState(this.heater);
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    heater.turnOn();
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    var msg = context.message;
    if (msg is BakeMessage) {
      return context.goTo(StateKey.forState<BakingState>());
    } else if (msg is ToastMessage) {
      return context.goTo(StateKey.forState<ToastingState>());
    }
    return context.unhandled();
  }

  @override
  FutureOr<void> onExit(TransitionContext context) {
    heater.turnOff();
  }
}

class ToastingState extends TreeState {
  String _color = 'dark';
  final HeatingElement heater;
  ToastingState(this.heater);
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    heater.setTimer(_color);
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    var msg = context.message;
    if (msg is SetToastingColorMessage) {
      _color = msg.color;
      return context.stay();
    }
    return context.unhandled();
  }

  @override
  FutureOr<void> onExit(TransitionContext context) {
    heater.clearTimer();
  }
}

class BakingState extends TreeState {
  int _temp;
  final HeatingElement heater;
  BakingState(this.heater);
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    heater.temp = _temp;
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    var msg = context.message;
    if (msg is SetTempMessage) {
      _temp = msg.temp;
      return context.stay();
    }
    return context.unhandled();
  }

  @override
  FutureOr<void> onExit(TransitionContext context) {
    heater.temp = 0;
  }
}

class DoorOpenState extends EmptyTreeState {
  final OvenLight light;
  DoorOpenState(this.light);
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    light.turnOn();
  }

  @override
  FutureOr<void> onExit(TransitionContext context) {
    light.turnOff();
  }
}

////////////////////////////////////////////////////////////////////////////////////////////////////
///
/// State tree
///

Root createToasterOvenBuilder(OvenLight light, HeatingElement heater) {
  return Root(
      createState: (_) => RootState(),
      initialChild: (_) => StateKey.forState<HeatingState>(),
      children: [
        Interior(
          createState: (_) => HeatingState(heater),
          initialChild: (_) => StateKey.forState<ToastingState>(),
          children: [
            Leaf(createState: (_) => ToastingState(heater)),
            Leaf(createState: (_) => BakingState(heater)),
          ],
        ),
        Leaf(createState: (_) => DoorOpenState(light)),
      ]);
}

abstract class HeatingElement {
  int temp;
  void turnOn();
  void turnOff();
  void setTimer(String toastColor);
  void clearTimer();
}

abstract class OvenLight {
  void turnOn();
  void turnOff();
}
