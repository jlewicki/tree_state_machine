import 'package:tree_state_machine/src/builders/fluent_tree_builders.dart';
import 'package:tree_state_machine/tree_state_machine.dart';

// Similar to https://github.com/dotnet-state-machine/stateless/blob/dev/example/BugTrackerExample/Bug.cs

class States {
  static final root = StateKey.named('Root');
  static final open = StateKey.named('Open');
  static final unassigned = StateKey.named('Unassigned');
  static final assigned = StateKey.named('Assigned');
  static final deferred = StateKey.named('Deferred');
  static final closed = StateKey.named('Closed');
}

//
// Messages
//
class Assign {
  final String assignee;
  Assign(this.assignee);
}

class Defer {}

class Close {}

class BugData {
  String title;
  String assignee;
}

//
// Channels
//
class AssignedChannel extends EntryChannel<String> {
  AssignedChannel() : super(States.assigned);
  String payloadFromAssign(Assign assign, MessageContext _) => assign.assignee;
}

//
// Definition
//
StateTreeBuilder bugStateTree() {
  var treeBuilder = StateTreeBuilder();

  var assigned = AssignedChannel();

  treeBuilder
      .dataState<BugData>(States.root)
      .withDataProvider(() => OwnedDataProvider(() => BugData()..title = 'New Bug'))
      .withInitialChild(States.open);

  treeBuilder
      .state(States.open)
      .withParent(States.root)
      .withInitialChild(States.unassigned)
      .onMessage<Assign>((b) => b.enterChannel(
            assigned,
            payload: assigned.payloadFromAssign,
            reenterTarget: true,
          ))
      .onMessage<Defer>((b) => b.goTo(States.deferred))
      .onMessage<Close>((b) => b.goTo(States.closed));

  treeBuilder
      .state(States.unassigned)
      .withParent(States.open)
      .onEnter<BugData, Object>((b) => b.updateData((d) => d.assignee = null));

  treeBuilder
      .state(States.assigned)
      .withParent(States.open)
      .onEnter<BugData, String>((b) => b.updateDataFromPayload(
            (data, payload) => data.assignee = payload,
            channel: assigned,
          ))
      .onExit<BugData>((b) => b.handle(
            (ctx, data) => sendEmailToAssignee(data, "You're off the hook."),
            label: 'sendEmail',
          ));

  treeBuilder
      .state(States.deferred)
      .withParent(States.root)
      .onEnter<BugData, Object>((b) => b.updateData(
            (d) => d.assignee = null,
            label: 'clear assignee',
          ))
      .onMessage<Assign>((b) => b.enterChannel(assigned, payload: assigned.payloadFromAssign));

  treeBuilder.state(States.closed).withParent(States.root);

  return treeBuilder;
}

void sendEmailToAssignee(BugData bug, String message) {
  print('${bug.assignee}, RE ${bug.title}: ${message}');
}

void main() async {
  var stateTree = bugStateTree();
  var sm = TreeStateMachine(stateTree);

  await sm.start();
  assert(sm.currentState.key == States.unassigned);

  // Assign it
  await sm.currentState.sendMessage(Assign('me'));
  assert(sm.currentState.key == States.assigned);
  var data = sm.currentState.findData<BugData>();
  assert(data.assignee == 'me');

  // Reassign it
  await sm.currentState.sendMessage(Assign('you'));
  assert(sm.currentState.key == States.assigned);
  data = sm.currentState.findData<BugData>();
  assert(data.assignee == 'you');

  // Defer it
  await sm.currentState.sendMessage(Defer());
  assert(sm.currentState.key == States.deferred);
  data = sm.currentState.findData<BugData>();
  assert(data.assignee == null);
}
