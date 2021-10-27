import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

//
// State keys
//
class States {
  static final root = StateKey('root');
  static final open = StateKey('open');
  static final assigned = StateKey('assigned');
  static final unassigned = StateKey('unassigned');
  static final deferred = StateKey('deferred');
  static final closed = StateKey('closed');
}

//
// Messages
//
class Assign {
  final String assignee;
  Assign(this.assignee);
}

enum Messages { close, defer }

//
// Channels
//
final assignedChannel = Channel<String>(States.assigned);

//
// State data
//
class BugData {
  String title = '';
  String? assignee = '';
}

//
// State tree
//
StateTreeBuilder bugTrackerStateTree() {
  var b = StateTreeBuilder.withDataRoot<BugData>(
    States.root,
    InitialData(() => BugData()..title = 'New Bug'),
    emptyDataState,
    InitialChild(States.open),
  );

  b.state(States.open, (b) {
    b.onMessage<Assign>((b) {
      b.enterChannel(assignedChannel, (_, msg) => msg.assignee, reenterTarget: true);
    });
    b.onMessageValue(Messages.close, (b) => b.goTo(States.closed));
    b.onMessageValue(Messages.defer, (b) => b.goTo(States.deferred));
  }, parent: States.root, initialChild: InitialChild(States.unassigned));

  b.state(States.unassigned, (b) {
    b.onEnterWithData<BugData>((b) {
      b.updateData((_, data) => data..assignee = null);
    });
  }, parent: States.open);

  b.state(States.assigned, (b) {
    b.onEnterFromChannel<String>(assignedChannel, (b) {
      b.updateData<BugData>((_, data, assignee) => data..assignee = assignee);
    });
    b.onExitWithData<BugData>((b) {
      b.run((ctx, data) => sendEmailToAssignee(data, "You're off the hook."),
          label: 'send email to assignee');
    });
  }, parent: States.open);

  b.state(States.deferred, (b) {
    b.onEnterWithData<BugData>((b) => b.updateData(
          (_, data) => data..assignee = null,
          label: 'clear assignee',
        ));
    b.onMessage<Assign>((b) {
      b.enterChannel(assignedChannel, (_, msg) => msg.assignee);
    });
  }, parent: States.root);

  b.state(States.closed, emptyState, parent: States.root);

  return b;
}

void sendEmailToAssignee(BugData bug, String message) {
  print('${bug.assignee}, RE ${bug.title}: $message');
}

void main() {
  // var treeBuilder = bugTrackerStateTree();
  // var sink = StringBuffer();
  // treeBuilder.format(sink, DotFormatter());
  // var dot = sink.toString();
  // var context = TreeBuildContext();
  // var node = treeBuilder.build(context);
}
