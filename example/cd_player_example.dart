import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

//
// Models
//
class Track {
  String name;
  Duration duration;
  Track(this.name, this.duration);
}

class Cd {
  final String name;
  final List<Track> tracks;
  Cd(this.name, this.tracks);
}

//
// State keys
//
class States {
  static final root = StateKey('root');
  static final idle = StateKey('idle');
  static final busy = StateKey('busy');
  static final playing = StateKey('playing');
  static final paused = StateKey('paused');
  static final open = StateKey('open');
  static final closed = StateKey('closed');
}

//
// Messages
//
class Stop {}

class Eject {}

class Play {}

class Pause {}

class Load {
  final Cd cd;
  Load(this.cd);
}

class Forward {
  final int trackCount;
  Forward(this.trackCount);
}

class Back {
  final int trackCount;
  Back(this.trackCount);
}

class MoveTrack {
  final int trackCount;
  MoveTrack(this.trackCount);
}

//
// Channels
//
final busyChannel = Channel<Cd>(States.busy);

//
// State Data
//
class RootData {
  Cd? cd;
}

class BusyData {
  Cd cd;
  int track = 0;
  Duration elapsedTime = Duration.zero;
  BusyData(this.cd);

  bool canMoveTrack(int trackCount) {
    var nextTrack = track + trackCount;
    return nextTrack >= 1 && nextTrack <= cd.tracks.length;
  }
}

//
// State tree
//
StateTreeBuilder cdPlayerStateTree() {
  var b = StateTreeBuilder.withDataRoot<RootData>(
    States.root,
    InitialData(() => RootData()),
    emptyDataState,
    InitialChild(States.idle),
  );

  b.state(States.idle, (b) {
    b.onMessage<Play>((b) => b.goTo(States.busy));
  }, initialChild: InitialChild(States.closed));

  b.state(States.open, (b) {
    b.onMessage<Eject>((b) => b.goTo(States.closed));
    b.onMessage<Load>((b) => b.stay(action: b.act.run(_updateCD)));
  }, parent: States.idle);

  b.state(States.closed, (b) {
    b.onEnterWithData<RootData>((b) {
      // Auto play if the cd is inserted (and we were aleady idle)
      b.when((ctx, data) => ctx.lca == States.idle && data.cd != null, (b) {
        b.post(value: Play());
      }, label: 'CD inserted');
    });
    b.onMessage<Eject>((b) => b.goTo(States.open));
  }, parent: States.idle);

  b.dataState<BusyData>(
    States.busy,
    InitialData.fromChannel(busyChannel, (Cd cd) => BusyData(cd)),
    (b) {
      b.onEnter((b) {
        b.updateData((_, busyData) => busyData
          ..track = 0
          ..elapsedTime = Duration.zero);
      });
      b.onMessage<Stop>((b) => b.goTo(States.idle));
    },
    initialChild: InitialChild(States.playing),
  );

  b.state(States.playing, (b) {
    b.onEnter((b) => b.schedule<Play>(
          value: Play(),
          duration: refreshDuration,
          periodic: true,
        ));
    b.onMessage<Pause>((b) => b.goTo(States.paused));
    b.onMessage<Play>((b) => b.stay(action: b.act.run(_playTrack)));
    b.onMessage<MoveTrack>((b) {
      b.when(
        (msgCtx, msg) => msgCtx.dataValueOrThrow<BusyData>().canMoveTrack(msg.trackCount),
        (b) {
          b.stay(action: b.act.run(_updateTrackCount, label: 'update next track'));
          // b.stay(action: b.act.updateData<BusyData>((msgCtx, msg, d) {
          //   return d..track += msg.trackCount;
          // }));
        },
        label: 'next track valid',
      ).otherwise(
        (b) {
          b.stay(action: b.act.post<Stop>((_, __) => Stop()));
        },
        label: 'next track invalid',
      );
    });
  }, parent: States.busy);

  b.state(States.paused, (b) {
    b.onMessage<Pause>((b) => b.stay());
    b.onMessage<Play>((b) => b.goTo(States.playing));
  }, parent: States.busy);

  return b;
}

void _updateCD(MessageContext ctx, Load msg) {
  ctx.dataOrThrow<RootData>().update((current) => current..cd = msg.cd);
}

final Duration refreshDuration = Duration(seconds: 1);

void _playTrack(MessageContext ctx, Object _) {
  var dataVal = ctx.dataOrThrow<BusyData>();
  var data = dataVal.value;
  var elapsed = data.elapsedTime + refreshDuration;
  var trackLength = data.cd.tracks[data.track].duration;
  if (elapsed >= trackLength) {
    ctx.post(Forward(1));
  } else {
    dataVal.update((_) => data..elapsedTime = elapsed);
  }
}

void _updateTrackCount(MessageContext ctx, MoveTrack msg) {
  ctx.dataOrThrow<BusyData>().update(((d) => d..track += msg.trackCount));
}

void main() {
  // var treeBuilder = cdPlayerStateTree();
  // var sink = StringBuffer();
  // treeBuilder.format(sink, DotFormatter());
  // var dot = sink.toString();
  // var context = TreeBuildContext();
  // var node = treeBuilder.build(context);
}
