import 'package:async/async.dart';
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

typedef AuthFuture = Future<Result<AuthorizedUser>>;

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
      b.enterChannel(authenticatingChannel, (_, msg) => msg);
    });
  }, parent: States.login);

  b.state(States.authenticating, (b) {
    b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
      b.post<AuthFuture>(getValue: (_, creds) => _login(creds, authService));
    });
    b.onMessage<AuthFuture>((b) {
      b.whenResult<AuthorizedUser>((_, msg) => msg, (b) {
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
    InitialData.fromAncestor(
        (AuthorizedUser user) => HomeData()..userSplashText = 'Welcome ' + user.firstName),
    (b) {},
    parent: States.authenticated,
  );

  return b;
}

AuthFuture _login(SubmitCredentials creds, AuthService authService) {
  return authService.authenticate(creds);
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
  @override
  Future<Result<AuthorizedUser>> authenticate(AuthenticationRequest request) async {
    return Result.error('nope');
  }

  @override
  Future<Result<AuthorizedUser>> register(RegistrationRequest request) async {
    return Result.error('nope');
  }
}

void main() {
  // var treeBuilder = loginStateTree(MockAuthService());
  // var sink = StringBuffer();
  // treeBuilder.format(sink, DotFormatter());
  // var dot = sink.toString();
  // var context = TreeBuildContext();
  // var node = treeBuilder.build(context);
}
