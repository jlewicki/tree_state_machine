import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/tree_builders.dart';

//
// Models and Services
//
class AuthorizedUser {
  final String firstName;
  final String lastName;
  final String email;
  AuthorizedUser(this.firstName, this.lastName, this.email);
}

class RegistrationRequest {
  final String email = '';
  final String password = '';
  final String firstName = '';
  final String lastName = '';
}

class AuthenticationRequest {
  final String email = '';
  final String password = '';
}

abstract class AuthService {
  Future<Result<AuthorizedUser>> authenticate(AuthenticationRequest request);
  Future<Result<AuthorizedUser>> register(RegistrationRequest request);
}

//
// State keys
//
class States {
  static final root = StateKey('root');
  static final unauthenticated = StateKey('unauthenticated');
  static final splash = StateKey('splash');
  static final login = StateKey('login');
  static final loginEntry = StateKey('loginEntry');
  static final authenticating = StateKey('authenticating');
  static final registration = StateKey('registration');
  static final credentialsRegistration = StateKey('credentialsRegistration');
  static final demographicsRegistration = StateKey('demographicsRegistration');
  static final authenticated = StateKey('authenticated');
  static final userHome = StateKey('userHome');
}

//
// Messages
//
class SubmitCredentials implements AuthenticationRequest {
  @override
  final String email;
  @override
  final String password;
  SubmitCredentials(this.email, this.password);
}

class SubmitDemographics {
  final String firstName;
  final String lastName;
  SubmitDemographics(this.firstName, this.lastName);
}

class AuthFuture {
  final FutureOr<Result<AuthorizedUser>> futureOr;
  AuthFuture(this.futureOr);
}

enum Messages { goToLogin, goToRegister, back, logout, submitRegistration }

//
// Channels
//
final authenticatingChannel = Channel<SubmitCredentials>(States.authenticating);
final authenticatedChannel = Channel<AuthorizedUser>(States.authenticated);

//
// State Data
//
class RegisterData implements RegistrationRequest {
  @override
  String email = '';
  @override
  String password = '';
  @override
  String firstName = '';
  @override
  String lastName = '';
  bool isBusy = false;
  String errorMessage = '';
}

class LoginData implements AuthenticationRequest {
  @override
  String email = '';
  @override
  String password = '';
  bool rememberMe = false;
  String errorMessage = '';
}

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
StateTreeBuilder loginStateTree(AuthService authService) {
  var b = StateTreeBuilder(initialState: States.unauthenticated);

  b.state(States.unauthenticated, (b) {
    b.onMessageValue(Messages.goToLogin, (b) => b.goTo(States.login));
    b.onMessageValue(Messages.goToRegister, (b) => b.goTo(States.registration));
  }, initialChild: InitialChild(States.splash));

  b.state(States.splash, emptyState, parent: States.unauthenticated);

  b.dataState<RegisterData>(
    States.registration,
    InitialData(() => RegisterData()),
    (b) {
      b.onMessageValue(Messages.submitRegistration, (b) {
        // Model the registration action as an asynchrous Result. The 'registering' status while the
        // operation is in progress is modeled as flag in RegisterData, and a state transition (to
        // Authenticated) does not occur until the operation is complete.
        b.whenResult<AuthorizedUser>(
          (msgCtx, msg, data) => _register(msgCtx, data, authService),
          (b) {
            b.enterChannel(authenticatedChannel, (_, __, ___, authorizedUser) => authorizedUser);
          },
          label: 'register user',
        ).otherwise(((b) {
          b.stay();
        }));
      });
    },
    parent: States.unauthenticated,
    initialChild: InitialChild(States.credentialsRegistration),
  );

  b.state(States.credentialsRegistration, (b) {
    b.onMessage<SubmitCredentials>((b) {
      b.goTo(States.demographicsRegistration,
          action: b.act.updateData<RegisterData>((_, msg, data) => data
            ..email = msg.email
            ..password = msg.password));
    });
  }, parent: States.registration);

  b.state(States.demographicsRegistration, (b) {
    b.onMessage<SubmitDemographics>((b) {
      b.unhandled(
        action: b.act.updateData<RegisterData>((_, msg, data) => data
          ..firstName = msg.firstName
          ..lastName = msg.lastName),
      );
    });
  }, parent: States.registration);

  b.dataState<LoginData>(
    States.login,
    InitialData(() => LoginData()),
    emptyDataState,
    parent: States.unauthenticated,
    initialChild: InitialChild(States.loginEntry),
  );

  b.state(States.loginEntry, (b) {
    b.onMessage<SubmitCredentials>((b) {
      // Model the 'logging in' status as a distinct state in the state machine. This is an
      // alternative design to modeling with a flag in state data, as was done with 'registering'
      // status.
      b.enterChannel(authenticatingChannel, (_, msg) => msg);
    });
  }, parent: States.login);

  b.state(States.authenticating, (b) {
    b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
      b.post<AuthFuture>(getMessage: (_, creds) => _login(creds, authService));
    });
    b.onMessage<AuthFuture>((b) {
      b.whenResult<AuthorizedUser>((_, msg) => msg.futureOr, (b) {
        b.enterChannel<AuthorizedUser>(authenticatedChannel, (_, __, user) => user);
      }).otherwise((b) {
        b.goTo(
          States.loginEntry,
          action: b.act.updateData<LoginData>(
              (_, __, current, err) => current..errorMessage = err.error.toString()),
        );
      });
    });
  }, parent: States.login);

  b.dataState<AuthenticatedData>(
    States.authenticated,
    InitialData.fromChannel(
      authenticatedChannel,
      (AuthorizedUser user) => AuthenticatedData(user),
    ),
    (b) {
      b.onMessageValue(Messages.logout, (b) {
        b.goTo(States.unauthenticated);
      });
    },
    initialChild: InitialChild(States.userHome),
  );

  b.dataState<HomeData>(
    States.userHome,
    InitialData.fromAncestor((AuthenticatedData authData) =>
        HomeData()..userSplashText = 'Welcome ' + authData.user.firstName),
    (b) {},
    parent: States.authenticated,
  );

  return b;
}

AuthFuture _login(SubmitCredentials creds, AuthService authService) {
  return AuthFuture(authService.authenticate(creds));
}

Future<Result<AuthorizedUser>> _register(
  MessageContext msgCtx,
  RegisterData registerData,
  AuthService authService,
) async {
  var errorMessage = '';
  var dataVal = msgCtx.dataOrThrow<RegisterData>();
  try {
    dataVal.update((_) => registerData
      ..isBusy = true
      ..errorMessage = '');

    var result = await authService.register(registerData);

    if (result.isError) {
      errorMessage = result.asError!.error.toString();
    }
    return result;
  } finally {
    dataVal.update((_) => registerData
      ..isBusy = false
      ..errorMessage = errorMessage);
  }
}

class MockAuthService implements AuthService {
  Future<Result<AuthorizedUser>> Function(AuthenticationRequest) doAuthenticate;
  Future<Result<AuthorizedUser>> Function(RegistrationRequest) doRegister;
  MockAuthService(this.doAuthenticate, this.doRegister);

  @override
  Future<Result<AuthorizedUser>> authenticate(AuthenticationRequest request) =>
      doAuthenticate(request);

  @override
  Future<Result<AuthorizedUser>> register(RegistrationRequest request) => doRegister(request);
}

void main() async {
  initLogging();

  var authService = MockAuthService(
    (req) async => Result.error('nope'),
    (req) async => Result.error('nope'),
  );

  var treeBuilder = loginStateTree(authService);
  var stateMachine = TreeStateMachine(treeBuilder);
  var currentState = await stateMachine.start();
  assert(currentState.key == States.splash);
  assert(currentState.isInState(States.unauthenticated));

  await currentState.post(Messages.goToLogin);
  assert(currentState.key == States.loginEntry);
  assert(currentState.isInState(States.login));

  authService.doAuthenticate = (req) async {
    return Result.value(AuthorizedUser('Chandler', 'Bing', 'chandler.bing@hotmail.com'));
  };
  await currentState.post(SubmitCredentials('chandler.bing@hotmail.com', 'friends123'));

  // Wait for login to complete
  await stateMachine.transitions.first;
  assert(currentState.key == States.userHome);
  assert(currentState.isInState(States.authenticated));
  assert(currentState.dataValue<AuthenticatedData>()!.user.email == 'chandler.bing@hotmail.com');

  await currentState.post(Messages.logout);
  assert(currentState.key == States.splash);
  assert(currentState.isInState(States.unauthenticated));

  await currentState.post(Messages.goToRegister);
  assert(currentState.key == States.credentialsRegistration);
  assert(currentState.isInState(States.registration));

  await currentState.post(SubmitCredentials('phoebes@smellycat.com', 'imnotursala'));
  assert(currentState.key == States.demographicsRegistration);

  await currentState.post(SubmitDemographics('Phoebe', 'Buffay'));

  authService.doRegister = (req) async {
    return Result.value(AuthorizedUser('Phoebe', 'Buffay', 'phoebes@smellycat.com'));
  };
  await currentState.post(Messages.submitRegistration);

  assert(currentState.key == States.userHome);
  assert(currentState.isInState(States.authenticated));
  assert(currentState.dataValue<AuthenticatedData>()!.user.email == 'phoebes@smellycat.com');
}

// Example of enabling logging output from tree_state_machine library.
void initLogging() {
  hierarchicalLoggingEnabled = true;
  Logger('tree_state_machine').level = Level.ALL;
  Logger.root.onRecord.listen((record) {
    print('${record.level.name}: ${record.time}: ${record.message}');
  });
}
