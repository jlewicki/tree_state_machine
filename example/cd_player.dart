import 'dart:async';
import 'package:tree_state_machine/tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// https://docs.spring.io/spring-statemachine/docs/3.0.0.M2/reference/#statemachine-examples-cdplayer

//
// Messages
//

class Track {
  String name;
  Duration duration;
}

class Cd {
  List<Track> tracks;
}

class Message {}

class Eject extends Message {}

class Play extends Message {}

class Pause extends Message {}

class Stop extends Message {}

class Load extends Message {
  final Cd cd;
  Load(this.cd);
}

class Forward extends Message {
  final int trackCount;
  Forward(this.trackCount);
}

class Back extends Message {
  final int trackCount;
  Back(this.trackCount);
}

//
// States
//

class Data {
  Cd cd;
}

class BusyData {
  Cd cd;
  int track;
  Duration elapsedTime;
}

class RootState extends DataTreeState<Data> {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    return context.unhandled();
  }
}

class BusyState extends DataTreeState<BusyData> {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    this.data.track = 0;
    this.data.elapsedTime = Duration.zero;
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Stop) {
      return context.goTo(StateKey.forState<IdleState>());
    }
    return context.unhandled();
  }
}

class IdleState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Play) {
      return context.goTo(StateKey.forState<BusyState>());
    }
    return context.unhandled();
  }
}

class PlayingState extends TreeState {
  static final Duration refreshDuration = Duration(seconds: 1);

  @override
  FutureOr<void> onEnter(TransitionContext context) {
    context.schedule(() => Play(), duration: refreshDuration, periodic: true);
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    final msg = context.message;
    if (msg is Pause) {
      return context.goTo(StateKey.forState<PausedState>());
    } else if (msg is Play) {
      var data = context.data<BusyData>();
      var elapsed = data.elapsedTime + refreshDuration;
      var trackLength = data.cd.tracks[data.track].duration;
      if (elapsed >= trackLength) {
        context.post(Forward(1));
        return context.stay();
      } else {
        return context.updateData<BusyData>((data) => data.elapsedTime = elapsed);
      }
    } else if (msg is Forward) {
      return _moveTrack(context, msg.trackCount);
    } else if (msg is Back) {
      return _moveTrack(context, -msg.trackCount);
    }
    return context.unhandled();
  }

  MessageResult _moveTrack(MessageContext context, int trackCount) {
    var data = context.data<BusyData>();
    var track = data.track + trackCount;
    if (track >= data.cd.tracks.length) {
      context.post(Stop());
      return context.stay();
    } else {
      return context.updateData<BusyData>((data) {
        data.track = track >= 0 ? track : 0;
        data.elapsedTime = Duration.zero;
      });
    }
  }
}

class PausedState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Pause) {
      return context.goTo(StateKey.forState<PlayingState>());
    }
    return context.unhandled();
  }
}

class ClosedState extends TreeState {
  @override
  FutureOr<void> onEnter(TransitionContext context) {
    if (context.data<Data>().cd != null) {
      context.post(Play());
    }
  }

  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    if (context.message is Eject) {
      return context.goTo(StateKey.forState<OpenState>());
    }
    return context.unhandled();
  }
}

class OpenState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) {
    final msg = context.message;
    if (msg is Eject) {
      return context.goTo(StateKey.forState<ClosedState>());
    } else if (msg is Load) {
      return context.updateData<Data>((current) => current.cd = msg.cd);
    }
    return context.unhandled();
  }
}

final stateMachine = TreeStateMachine(RootWithData(
  createState: (_) => RootState(),
  createProvider: () => OwnedDataProvider(() => Data()),
  initialChild: (_) => StateKey.forState<IdleState>(),
  children: [
    InteriorWithData(
      createState: (_) => BusyState(),
      createProvider: () => OwnedDataProvider(() => BusyData()),
      initialChild: (_) => StateKey.forState<PlayingState>(),
      children: [
        Leaf(createState: (_) => PlayingState()),
        Leaf(createState: (_) => PausedState()),
      ],
    ),
    Interior(
      createState: (_) => IdleState(),
      initialChild: (_) => StateKey.forState<ClosedState>(),
      children: [
        Leaf(createState: (_) => OpenState()),
        Leaf(createState: (_) => ClosedState()),
      ],
    ),
  ],
));
