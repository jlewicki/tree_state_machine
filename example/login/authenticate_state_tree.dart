import 'dart:async';

import 'package:async/async.dart';
import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/declarative_builders.dart';

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
  static const login = DataStateKey<LoginData>('login');
  static const loginEntry = StateKey('loginEntry');
  static const authenticating = StateKey('authenticating');
  static const registration = DataStateKey<RegisterData>('registration');
  static const credentialsRegistration = StateKey('credentialsRegistration');
  static const demographicsRegistration = StateKey('demographicsRegistration');
  static const authenticated = DataStateKey<AuthenticatedData>('authenticated');
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

DeclarativeStateTreeBuilder authenticateStateTree(
  AuthService authService, {
  StateKey initialState = States.login,
}) {
  var b =
      DeclarativeStateTreeBuilder(initialChild: initialState, logName: 'auth');

  b.dataState<RegisterData>(
    States.registration,
    InitialData(() => RegisterData()),
    (b) {
      b.onMessageValue(Messages.submitRegistration, (b) {
        // Model the registration action as an asynchrous Result. The 'registering' status while the
        // operation is in progress is modeled as flag in RegisterData, and a state transition (to
        // Authenticated) does not occur until the operation is complete.
        b.whenResult<AuthorizedUser>(
          (ctx) => _register(ctx.messageContext, ctx.data, authService),
          (b) {
            b.enterChannel(authenticatedChannel, (ctx) => ctx.context);
          },
          label: 'register user',
        ).otherwise(((b) {
          b.stay();
        }));
      });
    },
    initialChild: InitialChild(States.credentialsRegistration),
  );

  b.state(States.credentialsRegistration, (b) {
    b.onMessage<SubmitCredentials>((b) {
      b.goTo(States.demographicsRegistration,
          action: b.act.updateData<RegisterData>((ctx, data) => data
            ..email = ctx.message.email
            ..password = ctx.message.password));
    });
  }, parent: States.registration);

  b.state(States.demographicsRegistration, (b) {
    b.onMessage<SubmitDemographics>((b) {
      b.unhandled(
        action: b.act.updateData<RegisterData>((ctx, data) => data
          ..firstName = ctx.message.firstName
          ..lastName = ctx.message.lastName),
      );
    });
  }, parent: States.registration);

  b.dataState<LoginData>(
    States.login,
    InitialData(() => LoginData()),
    emptyState,
    initialChild: InitialChild(States.loginEntry),
  );

  b.state(States.loginEntry, (b) {
    b.onMessage<SubmitCredentials>((b) {
      // Model the 'logging in' status as a distinct state in the state machine. This is an
      // alternative design to modeling with a flag in state data, as was done with 'registering'
      // status.
      b.enterChannel(authenticatingChannel, (ctx) => ctx.message);
    });
  }, parent: States.login);

  b.state(States.authenticating, (b) {
    b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
      b.post<AuthFuture>(getMessage: (ctx) => _login(ctx.context, authService));
    });
    b.onMessage<AuthFuture>((b) {
      b.whenResult<AuthorizedUser>((ctx) => ctx.message.futureOr, (b) {
        b.enterChannel<AuthorizedUser>(
            authenticatedChannel, (ctx) => ctx.context);
      }).otherwise((b) {
        b.goTo(
          States.loginEntry,
          action: b.act.updateData<LoginData>(
              (ctx, err) => err..errorMessage = ctx.context.error.toString()),
        );
      });
    });
  }, parent: States.login);

  b.finalDataState<AuthenticatedData>(
    States.authenticated,
    InitialData.fromChannel(
      authenticatedChannel,
      (AuthorizedUser user) => AuthenticatedData(user),
    ),
    emptyFinalState,
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
  Future<Result<AuthorizedUser>> register(RegistrationRequest request) =>
      doRegister(request);
}

Future<void> main() async {
  var treeBuilder = authenticateStateTree(MockAuthService(
    (req) async => Result.error('nope'),
    (req) async => Result.error('nope'),
  ));

  var sb = StringBuffer();
  treeBuilder.format(sb, DotFormatter());
  print(sb.toString());
}
