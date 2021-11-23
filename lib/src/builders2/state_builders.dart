import 'package:tree_state_machine/src/machine/tree_state.dart';

/// Indicates that a value of type [P] must be provided when entering a state.
///
/// Channels are intended as a contract indicating that in order to transition to a particular
/// state, additional contextual information of type [P] must be provided by the transition source.
/// ```dart
/// // In order to enter the authenticating state, a SubmitCredentials value is
/// // required.
/// var authenticatingChannel = Channel<SubmitCredentials>(States.authenticating);
///
/// treeBuilder.state(States.loginEntry, (b) {
///     b.onMessage<SubmitCredentials>((b) {
///       // Provide a SubmitCredentials value when entering authenticating state
///       b.enterChannel(authenticatingChannel, (_, msg) => msg);
///     });
///   }, parent: States.login);
///
/// treeBuilder.state(States.authenticating, (b) {
///     b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
///       // The builder argument provides access to the SubmitCredentials, in this
///       // case as as argument to the getMessage function
///       b.post<AuthFuture>(getMessage: (_, creds) => _login(creds, authService));
///     });
///  }, parent: States.login)
/// ```
class Channel<P> {
  /// The state to enter for this channel.
  final StateKey to;

  /// A descriptive label for this channel.
  final String? label;

  /// Constructs a channel for the [to] state.
  Channel(this.to, {this.label});
}
