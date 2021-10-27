part of tree_builders;

class Channel<P> {
  final StateKey to;
  final String? label;
  Channel(this.to, {this.label});
  _ChannelEntry<P, M> entry<M>(FutureOr<P> Function(MessageContext ctx, M message)? payload) {
    return _ChannelEntry(this, payload);
  }

  _ChannelEntryWithData<P, M, D> entryWithData<M, D>(
    FutureOr<P> Function(MessageContext msgCtx, M msg, D data)? payload,
  ) {
    return _ChannelEntryWithData<P, M, D>(this, payload);
  }

  _ChannelEntryWithResult<P, M, T> entryWithResult<M, T>(
    FutureOr<P> Function(MessageContext msgCtx, M msg, T ctx)? payload,
  ) {
    return _ChannelEntryWithResult<P, M, T>(this, payload);
  }

  _ChannelEntryWithDataAndResult<P, M, D, T> entryWithDataAndResult<M, D, T>(
    FutureOr<P> Function(MessageContext msgCtx, M msg, D data, T ctx)? payload,
  ) {
    return _ChannelEntryWithDataAndResult<P, M, D, T>(this, payload);
  }

  _ChannelExit<P> exit() {
    return _ChannelExit(this);
  }
}

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

class _ChannelExit<P> {
  final Channel<P> channel;
  _ChannelExit(this.channel);
}
