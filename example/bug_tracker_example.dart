import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';

//
// State keys
//
class States {
  static final root = DataStateKey<BugData>('root');
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
final assignedChannel = EntryChannel<String>(States.assigned);

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
DeclarativeStateTreeBuilder bugTrackerStateTree() {
  var b = DeclarativeStateTreeBuilder.withDataRoot<BugData>(
    States.root,
    InitialData(() => BugData()..title = 'New Bug'),
    emptyState,
    InitialChild(States.open),
  );

  b.state(States.open, (b) {
    b.onMessage<Assign>((b) {
      b.enterChannel(assignedChannel, (ctx) => ctx.message.assignee,
          reenterTarget: true);
    });
    b.onMessageValue(Messages.close, (b) => b.goTo(States.closed));
    b.onMessageValue(Messages.defer, (b) => b.goTo(States.deferred));
  }, parent: States.root, initialChild: InitialChild(States.unassigned));

  b.state(States.unassigned, (b) {
    b.onEnter((b) {
      b.updateData<BugData>((ctx) => ctx.data..assignee = null);
    });
  }, parent: States.open);

  b.state(States.assigned, (b) {
    b.onEnterFromChannel<String>(assignedChannel, (b) {
      b.updateData<BugData>((ctx) => ctx.data..assignee = ctx.context);
    });
    b.onExitWithData<BugData>((b) {
      b.run((ctx) => sendEmailToAssignee(ctx.context, "You're off the hook."),
          label: 'send email to assignee');
    });
  }, parent: States.open);

  b.state(States.deferred, (b) {
    b.onEnter((b) => b.updateData<BugData>(
          (ctx) => ctx.data..assignee = null,
          label: 'clear assignee',
        ));
    b.onMessage<Assign>((b) {
      b.enterChannel<String>(assignedChannel, (ctx) => ctx.message.assignee);
    });
  }, parent: States.root);

  b.state(States.closed, emptyState, parent: States.root);

  return b;
}

void sendEmailToAssignee(BugData bug, String message) {
  print('${bug.assignee}, RE ${bug.title}: $message');
}

Future<void> main() async {
  var treeBuilder = bugTrackerStateTree();
  var stateMachine = TreeStateMachine(treeBuilder);

  var currentState = await stateMachine.start();
  assert(currentState.key == States.unassigned);

  await currentState.post(Assign('Joey'));
  assert(currentState.key == States.assigned);
  assert(currentState.dataValue<BugData>()!.assignee == 'Joey');

  await currentState.post(Messages.defer);
  assert(currentState.key == States.deferred);
  assert(currentState.dataValue<BugData>()!.assignee == null);

  await currentState.post(Assign('Rachel'));
  assert(currentState.key == States.assigned);
  assert(currentState.dataValue<BugData>()!.assignee == 'Rachel');

  await currentState.post(Messages.close);
  assert(currentState.key == States.closed);

  var sb = StringBuffer();
  treeBuilder.format(sb, DotFormatter());
  print(sb.toString());
}
