import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

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
  static final authenticated = StateKey('authenticated');
  static final userHome = StateKey('userHome');
}

//
// Messages
//
enum Messages { goToLogin, goToRegister }

//
// Channnels
//
class AuthenticatePayload {
  StateKey authState = auth.States.login;
}

final authenticateChannel = Channel<AuthenticatePayload>(States.authenticate);
final authenticatedChannel = Channel<AuthorizedUser>(States.authenticated);

//
// State Data
//
class AuthenticatedData {
  final AuthorizedUser user;
  AuthenticatedData(this.user);
}

class HomeData {
  String userSplashText = '';
}

//
// State tree
//
StateTreeBuilder appStateTree(AuthService authService) {
  var b = StateTreeBuilder(initialState: States.unauthenticated);

  b.state(States.splash, (b) {
    b.onMessageValue(
      Messages.goToLogin,
      (b) => b.enterChannel(authenticateChannel, (_, __) => auth.States.login),
    );
    b.onMessageValue(
      Messages.goToRegister,
      (b) => b.enterChannel(authenticateChannel, (_, __) => auth.States.registration),
    );
  });

  b.machineState(
    States.authenticate,
    InitialMachine.fromTree((_) => auth.authenticateStateTree(authService)),
    (b) {
      b.onMachineDone((b) => b.enterChannel(
            authenticatedChannel,
            (finalState) => finalState.dataValue<AuthorizedUser>(),
          ));
    },
  );

  return b;
}

class MockAuthService implements AuthService {
  Future<Result<AuthorizedUser>> Function(auth.AuthenticationRequest) doAuthenticate;
  Future<Result<AuthorizedUser>> Function(auth.RegistrationRequest) doRegister;
  MockAuthService(this.doAuthenticate, this.doRegister);

  @override
  Future<Result<AuthorizedUser>> authenticate(auth.AuthenticationRequest request) =>
      doAuthenticate(request);

  @override
  Future<Result<AuthorizedUser>> register(auth.RegistrationRequest request) => doRegister(request);
}

void main() async {
  initLogging();

  var authService = MockAuthService(
    (req) async => Result.error('nope'),
    (req) async => Result.error('nope'),
  );

  var treeBuilder = appStateTree(authService);
  var stateMachine = TreeStateMachine(treeBuilder);
  var currentState = await stateMachine.start();
  assert(currentState.key == States.splash);

  // await currentState.post(Messages.goToLogin);
  // assert(currentState.key == States.loginEntry);
  // assert(currentState.isInState(States.login));

  // authService.doAuthenticate = (req) async {
  //   return Result.value(AuthorizedUser('Chandler', 'Bing', 'chandler.bing@hotmail.com'));
  // };
  // await currentState.post(SubmitCredentials('chandler.bing@hotmail.com', 'friends123'));

  // // Wait for login to complete
  // await stateMachine.transitions.first;
  // assert(currentState.key == States.authenticated);
  // assert(currentState.dataValue<AuthenticatedData>()!.user.email == 'chandler.bing@hotmail.com');
  // assert(stateMachine.isDone);

  // await currentState.post(Messages.logout);
  // assert(currentState.key == States.splash);
  // assert(currentState.isInState(States.unauthenticated));

  // await currentState.post(Messages.goToRegister);
  // assert(currentState.key == States.credentialsRegistration);
  // assert(currentState.isInState(States.registration));

  // await currentState.post(SubmitCredentials('phoebes@smellycat.com', 'imnotursala'));
  // assert(currentState.key == States.demographicsRegistration);

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
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
