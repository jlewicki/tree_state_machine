import 'package:tree_state_machine/src/builders/fluent_tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// https://docs.spring.io/spring-statemachine/docs/3.0.0.M2/reference/#statemachine-examples-cdplayer

//
// Messages
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

class MoveTrack extends Message {
  final int trackCount;
  MoveTrack(this.trackCount);
}

//
// State Data
//

class Data {
  Cd cd;
}

class BusyData {
  Cd cd;
  int track;
  Duration elapsedTime;

  bool canMoveTrack(int trackCount) {
    var nextTrack = track + trackCount;
    return nextTrack >= 1 && nextTrack <= cd.tracks.length;
  }
}

class States {
  static final StateKey root = StateKey.named('root');
  static final StateKey idle = StateKey.named('idle');
  static final StateKey busy = StateKey.named('busy');
  static final StateKey playing = StateKey.named('playing');
  static final StateKey paused = StateKey.named('paused');
  static final StateKey open = StateKey.named('open');
  static final StateKey closed = StateKey.named('closed');
}

final Duration refreshDuration = Duration(seconds: 1);

void _playTrack(MessageContext ctx) {
  var data = ctx.findData<BusyData>();
  var elapsed = data.elapsedTime + refreshDuration;
  var trackLength = data.cd.tracks[data.track].duration;
  if (elapsed >= trackLength) {
    ctx.post(Forward(1));
  } else {
    ctx.updateData<BusyData>((data) => data.elapsedTime = elapsed);
  }
}

StateTreeBuilder cdPlayerStateTree() {
  var treeBuilder = StateTreeBuilder.rooted(States.root, States.idle);

  treeBuilder.dataState<Data>(States.root).withDataProvider(() => OwnedDataProvider(() => Data()));

  treeBuilder
      .state(States.idle)
      .withInitialChild(States.closed)
      .onMessage<Play>((b) => b.goTo(States.busy));

  treeBuilder
      .state(States.open)
      .withParent(States.idle)
      .onMessage<Eject>((b) => b.goTo(States.closed))
      .onMessage<Load>((b) => b.stay(
            before: (msg, ctx) => ctx.updateData<Data>((current) => current.cd = msg.cd),
          ));

  treeBuilder
      .state(States.closed)
      .withParent(States.idle)
      .onEnter<Data, Object>((b) => b.post<Play>(
            value: Play(),
            // Auto play if the cd is inserted (and we were aleady idle)
            when: (ctx, data) => ctx.lca == States.idle && data.cd != null,
            whenLabel: 'CD inserted',
          ))
      .onMessage<Eject>((b) => b.goTo(States.open));

  treeBuilder
      .dataState<BusyData>(States.busy)
      .withDataProvider(() => OwnedDataProvider(() => BusyData()))
      .withInitialChild(States.playing)
      .onEnter<BusyData, Object>((b) => b.updateDataFromPayload(
            (data, payload) => data
              ..track = 0
              ..elapsedTime = Duration.zero,
          ))
      .onMessage<Stop>((b) => b.goTo(States.idle));

  treeBuilder
      .state(States.playing)
      .withParent(States.busy)
      .onEnter((b) => b.schedule<Play>(
            value: Play(),
            duration: refreshDuration,
            periodic: true,
          ))
      .onMessage<Pause>((b) => b.goTo(States.paused))
      .onMessage<Play>((b) => b.stay(before: (m, ctx) => _playTrack(ctx)))
      .onMessage<MoveTrack>((b) => b.stay(
          before: (m, ctx) => ctx.updateData<BusyData>((d) => d.track += m.trackCount),
          when: (m, ctx) => ctx.findData<BusyData>().canMoveTrack(m.trackCount),
          whenLabel: "next track valid"))
      .onMessage<MoveTrack>((b) => b.post<Stop>(
          value: Stop(),
          when: (m, ctx) => !ctx.findData<BusyData>().canMoveTrack(m.trackCount),
          whenLabel: "next track invalid"));

  treeBuilder
      .state(States.paused)
      .withParent(States.busy)
      .onMessage<Pause>((b) => b.goTo(States.playing))
      .onMessage<Play>((b) => b.goTo(States.playing));

  return treeBuilder;
}

void main() async {
  var stateTree = cdPlayerStateTree();
  var sm = TreeStateMachine(stateTree);

  var cd = Cd('Greatest Hits', [
    Track('Bohemian Rhapsody', Duration(minutes: 5, seconds: 56)),
    Track('Another One Bites the Dust', Duration(minutes: 3, seconds: 36)),
  ]);

  await sm.start();
  assert(sm.currentState.key == States.closed);
  assert(sm.currentState.findData<Data>().cd == null);

  await sm.currentState.sendMessage(Eject());
  assert(sm.currentState.key == States.open);

  await sm.currentState.sendMessage(Load(cd));

  await sm.currentState.sendMessage(Play());
  assert(sm.currentState.key == States.playing);

  await Future.delayed(Duration(seconds: 3));

  assert(sm.currentState.key == States.playing);
  await sm.currentState.sendMessage(Pause());
  assert(sm.currentState.key == States.paused);

  await sm.currentState.sendMessage(Stop());
  assert(sm.currentState.key == States.closed);
}
