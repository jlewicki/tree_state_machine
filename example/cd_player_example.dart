import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';

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
  static final root = DataStateKey<RootData>('root');
  static final idle = StateKey('idle');
  static final busy = DataStateKey<BusyData>('busy');
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
DeclarativeStateTreeBuilder cdPlayerStateTree() {
  var b = DeclarativeStateTreeBuilder.withDataRoot<RootData>(
    States.root,
    InitialData(() => RootData()),
    emptyState,
    InitialChild(States.idle),
  );

  b.state(States.idle, (b) {
    b.onMessage<Play>((b) => b.goTo(States.busy));
  }, initialChild: InitialChild(States.closed));

  b.state(States.open, (b) {
    b.onMessage<Eject>((b) => b.goTo(States.closed));
    b.onMessage<Load>((b) {
      b.action(
          b.act.updateData<RootData>((ctx, data) => data..cd = ctx.message.cd));
    });
  }, parent: States.idle);

  b.state(States.closed, (b) {
    b.onEnterWithData<RootData>((b) {
      // Auto play if the cd is inserted (and we were aleady idle)
      b.when(
          (ctx) =>
              ctx.transitionContext.lca == States.idle &&
              ctx.context.cd != null, (b) {
        b.post(message: Play());
      }, label: 'CD inserted');
    });
    b.onMessage<Eject>((b) => b.goTo(States.open));
  }, parent: States.idle);

  b.dataState<BusyData>(
    States.busy,
    InitialData.fromChannel(busyChannel, (Cd cd) => BusyData(cd)),
    (b) {
      b.onEnter((b) {
        b.updateOwnData((ctx) => ctx.data
          ..track = 0
          ..elapsedTime = Duration.zero);
      });
      b.onMessage<Stop>((b) => b.goTo(States.idle));
    },
    initialChild: InitialChild(States.playing),
  );

  b.state(States.playing, (b) {
    b.onEnter((b) => b.schedule<Play>(
          message: Play(),
          duration: refreshDuration,
          periodic: true,
        ));
    b.onMessage<Pause>((b) => b.goTo(States.paused));
    b.onMessage<Play>(
        (b) => b.action(b.act.run(_playTrack, label: 'play track')));
    b.onMessage<MoveTrack>((b) {
      b.when(
        (ctx) => ctx.messageContext
            .dataValueOrThrow<BusyData>()
            .canMoveTrack(ctx.message.trackCount),
        (b) {
          b.action(b.act.updateData<BusyData>(
            (ctx, data) => data..track += ctx.message.trackCount,
            label: 'update next track',
          ));
        },
        label: 'next track valid',
      ).otherwise(
        (b) {
          b.stay(action: b.act.post<Stop>(message: Stop()));
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

final Duration refreshDuration = Duration(seconds: 1);

void _playTrack(MessageHandlerContext<Play, void, void> ctx) {
  ctx.messageContext.dataOrThrow<BusyData>().update((data) {
    var elapsed = data.elapsedTime + refreshDuration;
    var trackLength = data.cd.tracks[data.track].duration;
    if (elapsed >= trackLength) {
      ctx.messageContext.post(Forward(1));
    } else {
      data = data..elapsedTime = elapsed;
    }
    return data;
  });
}

Future<void> main() async {
  var treeBuilder = cdPlayerStateTree();
  var sb = StringBuffer();
  treeBuilder.format(sb, DotFormatter());
  print(sb.toString());
}
