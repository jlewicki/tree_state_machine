part of tree_builders;

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

  // _ChannelEntry<P, M> _entry<M>(FutureOr<P> Function(MessageContext ctx, M message)? payload) {
  //   return _ChannelEntry(this, payload);
  // }

  _ChannelEntryWithData<P, M, D> _entryWithData<M, D>(
    FutureOr<P> Function(MessageContext msgCtx, M msg, D data)? payload,
  ) {
    return _ChannelEntryWithData<P, M, D>(this, payload);
  }

  _ChannelEntryWithResult<P, M, T> _entryWithResult<M, T>(
    FutureOr<P> Function(MessageContext msgCtx, M msg, T ctx)? payload,
  ) {
    return _ChannelEntryWithResult<P, M, T>(this, payload);
  }

  _ChannelEntryWithDataAndResult<P, M, D, T> _entryWithDataAndResult<M, D, T>(
    FutureOr<P> Function(MessageContext msgCtx, M msg, D data, T ctx)? payload,
  ) {
    return _ChannelEntryWithDataAndResult<P, M, D, T>(this, payload);
  }
}

// TODO: these entry class are not particularly useful.  Consider removing them
class _ChannelEntry<P, M> {
  final Channel<P> channel;
  final FutureOr<P> Function(MessageContext ctx, M message)? payload;
  _ChannelEntry(this.channel, this.payload);

  void enter(MessageHandlerBuilder<M> builder, bool reenterTarget) {
    builder.goTo(channel.to, payload: payload, reenterTarget: reenterTarget);
  }
}

class _ChannelEntryWithData<P, M, D> {
  final Channel<P> channel;
  final FutureOr<P> Function(MessageContext msgCtx, M msg, D data)? payload;
  _ChannelEntryWithData(this.channel, this.payload);

  void enter(DataMessageHandlerBuilder<M, D> builder, bool reenterTarget) {
    builder.goTo(channel.to, payload: payload, reenterTarget: reenterTarget);
  }
}

class _ChannelEntryWithResult<P, M, T> {
  final Channel<P> channel;
  final FutureOr<P> Function(MessageContext msgCtx, M msg, T ctx)? payload;
  _ChannelEntryWithResult(this.channel, this.payload);

  void enter(ContinuationMessageHandlerBuilder<M, T> builder, bool reenterTarget) {
    builder.goTo(channel.to, payload: payload, reenterTarget: reenterTarget);
  }
}

class _ChannelEntryWithDataAndResult<P, M, D, T> {
  final Channel<P> channel;
  final FutureOr<P> Function(MessageContext msgCtx, M msg, D data, T ctx)? payload;
  _ChannelEntryWithDataAndResult(this.channel, this.payload);

  void enter(ContinuationWithDataMessageHandlerBuilder<M, D, T> builder, bool reenterTarget) {
    builder.goTo(channel.to, payload: payload, reenterTarget: reenterTarget);
  }
}
