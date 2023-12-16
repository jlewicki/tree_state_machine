import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import 'authenticate_state_tree.dart' as auth;

typedef AuthService = auth.AuthService;
typedef AuthorizedUser = auth.AuthorizedUser;

//
// State keys
//
class States {
  static final unauthenticated = StateKey('unauthenticated');
  static final splash = StateKey('splash');
  static final authenticate = StateKey('authenticate');
  static final authenticated = DataStateKey<AuthorizedUser>('authenticated');
  static final userHome = StateKey('userHome');
}

//
// Messages
//
enum Messages { goToLogin, goToRegister, logout }

//
// Channnels
//

// Paylod is the initial state in the nested state machine enter.
final authenticateChannel = Channel<StateKey>(States.authenticate);
final authenticatedChannel = Channel<AuthorizedUser>(States.authenticated);

//
// State Data
//

class HomeData {
  String userSplashText = '';
}

//
// State tree
//
DeclarativeStateTreeBuilder appStateTree(AuthService authService) {
  var b =
      DeclarativeStateTreeBuilder(initialChild: States.splash, logName: 'app');

  b.state(States.splash, (b) {
    b.onMessageValue(
      Messages.goToLogin,
      (b) => b.enterChannel<StateKey>(
          authenticateChannel, (_) => auth.States.login),
    );
    b.onMessageValue(
      Messages.goToRegister,
      (b) =>
          b.enterChannel(authenticateChannel, (_) => auth.States.registration),
    );
  });

  b.machineState(
    States.authenticate,
    InitialMachine.fromTree(
        (transCtx) => auth
            .authenticateStateTree(
              authService,
              initialState: transCtx.payload as StateKey,
            )
            .toTreeBuilder(),
        label: 'Authenticate Machine'),
    (b) {
      b.onMachineDone((b) => b.enterChannel(
            authenticatedChannel,
            (ctx) => ctx.context.dataValue<auth.AuthenticatedData>()!.user,
          ));
    },
  );

  b.dataState<AuthorizedUser>(
    States.authenticated,
    InitialData.fromChannel(authenticatedChannel, (AuthorizedUser p) => p),
    (b) {
      b.onMessageValue(Messages.logout, (b) => b.goTo(States.splash));
    },
  );

  return b;
}

class MockAuthService implements AuthService {
  Future<Result<AuthorizedUser>> Function(auth.AuthenticationRequest)
      doAuthenticate;
  Future<Result<AuthorizedUser>> Function(auth.RegistrationRequest) doRegister;
  MockAuthService(this.doAuthenticate, this.doRegister);

  @override
  Future<Result<AuthorizedUser>> authenticate(
          auth.AuthenticationRequest request) =>
      doAuthenticate(request);

  @override
  Future<Result<AuthorizedUser>> register(auth.RegistrationRequest request) =>
      doRegister(request);
}

void main() async {
  initLogging();

  var authService = MockAuthService(
    (req) async => Result.error('nope'),
    (req) async => Result.error('nope'),
  );

  var logger = Logger('LogFilter');
  var loggingFilter = TreeStateFilter(
    name: 'loggingFilter',
    onMessage: (msgCtx, next) {
      logger.info(
          'State ${msgCtx.handlingState} is handling message ${msgCtx.message}');
      return next();
    },
  );

  var declBuilder = appStateTree(authService);
  declBuilder.extendStates((_, b) => b.filter(loggingFilter));
  var stateMachine = TreeStateMachine(declBuilder);

  var currentState = await stateMachine.start();
  assert(currentState.key == States.splash);

  await currentState.post(Messages.goToLogin);
  assert(currentState.key == States.authenticate);

  var nestedState =
      currentState.dataValue<NestedMachineData>()!.nestedCurrentState;
  assert(nestedState.isInState(auth.States.login));
  assert(nestedState.key == auth.States.loginEntry);

  authService.doAuthenticate = (req) async {
    return Result.value(
        AuthorizedUser('Chandler', 'Bing', 'chandler.bing@hotmail.com'));
  };
  await currentState
      .post(auth.SubmitCredentials('chandler.bing@hotmail.com', 'friends123'));

  // Check that nested state machine finished
  assert(nestedState.key == auth.States.authenticated);
  assert(nestedState.dataValue<auth.AuthenticatedData>()!.user.email ==
      'chandler.bing@hotmail.com');
  assert(nestedState.stateMachine.isDone);

  await stateMachine.transitions
      .firstWhere((t) => t.to == States.authenticated);
  await currentState.post(Messages.logout);
  assert(currentState.key == States.splash);

  await currentState.post(Messages.goToRegister);
  assert(currentState.key == States.authenticate);

  nestedState = currentState.dataValue<NestedMachineData>()!.nestedCurrentState;
  assert(nestedState.isInState(auth.States.registration));
  assert(nestedState.key == auth.States.credentialsRegistration);

  await currentState
      .post(auth.SubmitCredentials('phoebes@smellycat.com', 'imnotursala'));
  assert(nestedState.key == auth.States.demographicsRegistration);

  var sb = StringBuffer();
  declBuilder.format(sb, DotFormatter());
  print(sb.toString());

  // await currentState.post(SubmitDemographics('Phoebe', 'Buffay'));

  // authService.doRegister = (req) async {
  //   return Result.value(AuthorizedUser('Phoebe', 'Buffay', 'phoebes@smellycat.com'));
  // };
  // await currentState.post(Messages.submitRegistration);

  // assert(currentState.key == States.userHome);
  // assert(currentState.isInState(States.authenticated));
  // assert(currentState.dataValue<AuthenticatedData>()!.user.email == 'phoebes@smellycat.com');
}

// Example of enabling logging output from tree_state_machine library.
void initLogging() {
  hierarchicalLoggingEnabled = true;
  Logger('tree_state_machine').level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print(
        '${record.level.name}: ${record.time}: ${record.loggerName}: ${record.message}');
  });
}
