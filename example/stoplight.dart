import 'dart:async';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// https://www.state-machine.com/doc/AN_PELICAN.pdf
// https://barrgroup.com/embedded-systems/how-to/introduction-hierarchical-state-machines

//
// Messages
//
abstract class Message {}

class TurnOff implements Message {}

class TurnOn implements Message {}

class Timeout implements Message {}

class PedestriansWaiting implements Message {}

//
// State Data
//
enum TrafficLightColor { red, yellow, green }
enum CrossingSymbol { walk, dontWalk, none }

abstract class Hardware {
  signalPedestrians(CrossingSymbol symbol);
  signalCars(TrafficLightColor color);
}

//
// States
//

class RootState extends DataTreeState<Hardware> {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.unhandled();
  }
}

class OperationalState extends TreeState {
  Hardware hardware;
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    hardware.signalCars(TrafficLightColor.red);
    hardware.signalPedestrians(CrossingSymbol.dontWalk);
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is TurnOff) {
      return context.goTo(StateKey.forState<OfflineState>());
    }
    return context.unhandled();
  }
}

class CarsEnabledState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    context.findData<Hardware>().signalPedestrians(CrossingSymbol.dontWalk);
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.unhandled();
  }
}

class CarsGreenState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    context.findData<Hardware>().signalCars(TrafficLightColor.green);
    context.schedule(() => Timeout(), duration: Duration(seconds: 8));
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.unhandled();
  }
}

class CarsGreenNoPedsState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is PedestriansWaiting) {
      return context.goTo(StateKey.forState<CarsGreenPedsWaitingState>());
    } else if (context.message is Timeout) {
      return context.goTo(StateKey.forState<CarsGreenInterruptableState>());
    }
    return context.unhandled();
  }
}

class CarsGreenInterruptableState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is PedestriansWaiting) {
      return context.goTo(StateKey.forState<CarsYellowState>());
    }
    return context.unhandled();
  }
}

class CarsGreenPedsWaitingState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Timeout) {
      return context.goTo(StateKey.forState<CarsYellowState>());
    }
    return context.unhandled();
  }
}

class CarsYellowState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    context.findData<Hardware>().signalCars(TrafficLightColor.yellow);
    context.schedule(() => Timeout(), duration: Duration(seconds: 3));
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Timeout) {
      return context.goTo(StateKey.forState<PedsEnabledState>());
    }
    return context.unhandled();
  }
}

class PedsEnabledState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    context.findData<Hardware>().signalCars(TrafficLightColor.red);
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.unhandled();
  }
}

class PedsWalkingState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    context.schedule(() => Timeout(), duration: Duration(seconds: 8));
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Timeout) {
      return context.goTo(StateKey.forState<PedsFlashingState>());
    }

    return context.unhandled();
  }
}

class PedsFlashingState extends TreeState {
  int flashCount = 0;

  @override
  FutureOr<void> onEnter(TransitionContext context) {
    flashCount = 0;
    context.schedule(() => Timeout(), duration: Duration(seconds: 1), periodic: true);
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Timeout) {
      flashCount++;
      if (flashCount == 7) {
        return context.goTo(StateKey.forState<CarsEnabledState>());
      } else {
        context
            .findData<Hardware>()
            .signalPedestrians(flashCount % 2 == 1 ? CrossingSymbol.none : CrossingSymbol.walk);
      }
    }
    return context.unhandled();
  }
}

class OfflineState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is TurnOn) {
      return context.goTo(StateKey.forState<OperationalState>());
    }
    return context.unhandled();
  }
}

//
// State Tree
//
Root createTrafficLightBuilder(Hardware hardware) {
  return RootWithData(
    createState: (_) => RootState(),
    createProvider: () => OwnedDataProvider(() => hardware),
    initialChild: (_) => StateKey.forState<OperationalState>(),
    children: [
      Interior(
        createState: (_) => OperationalState(),
        initialChild: (_) => StateKey.forState<CarsEnabledState>(),
        children: [
          Interior(
            createState: (_) => CarsEnabledState(),
            initialChild: (_) => StateKey.forState<CarsGreenState>(),
            children: [
              Interior(
                createState: (_) => CarsGreenState(),
                initialChild: (_) => StateKey.forState<CarsGreenNoPedsState>(),
                children: [
                  Leaf(createState: (_) => CarsGreenNoPedsState()),
                  Leaf(createState: (_) => CarsGreenInterruptableState()),
                  Leaf(createState: (_) => CarsGreenPedsWaitingState()),
                ],
              ),
              Leaf(createState: (_) => CarsYellowState()),
            ],
          ),
          Interior(
            createState: (_) => PedsEnabledState(),
            initialChild: (_) => StateKey.forState<PedsWalkingState>(),
            children: [
              Leaf(createState: (_) => PedsWalkingState()),
              Leaf(createState: (_) => PedsFlashingState())
            ],
          ),
        ],
      ),
      Leaf(createState: (_) => OfflineState())
    ],
  );
}
