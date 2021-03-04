part of fluent_tree_builders;

enum _TransitionHandlerType { post, schedule, updateData, replaceData, opaqueHandler, channelEntry }

/// Defines methods for building a transition handler that expects state data of type [D].
///
/// A [TransitionHandlerBuilder] is typically obtained by calling [StateBuilder.onEnter] or
/// [StateBuilder.onExit].
class TransitionHandlerBuilder<D> {
  final StateKey _forState;
  final List<_TransitionHandlerInfo> _handlers = [];

  TransitionHandlerBuilder(this._forState);

  /// Indicates that a message of type [M] should be posted to the state machine when the
  /// transition occurs.
  ///
  /// If [getValue] is provided, this function will be called to obtain the message to post.
  /// Otherwise [value] will be posted.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and the
  /// scheduling will occur only if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  TransitionHandlerBuilder<D> post<M>({
    FutureOr<M> Function(TransitionContext ctx) getValue,
    M value,
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String label,
    String whenLabel,
  }) {
    if (getValue == null && value == null) {
      throw new ArgumentError("post or value must be provided");
    } else if (getValue != null && value != null) {
      throw ArgumentError('getValue or value must be provided');
    }

    var messageType = TypeLiteral<M>().type;
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.post,
      transitionHandler: (ctx) => ctx.post(getValue != null ? getValue(ctx) : value),
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      postMessageType: messageType,
      handlerLabel: label,
    ));
    return this;
  }

  /// Indicates that a message of type [M] should be scheduled to be posted to the state machine
  /// when the transition occurs.
  ///
  /// If [getValue] is provided, this function will be called to obtain the message to schedule
  /// Otherwise [value] will be scheduled. The scheduling is performed by [TransitionContext.schedule].
  /// Refer to the documentation for this method for usage of the [duration] and [periodic] arguments.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and the
  /// scheduling will occur only if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  TransitionHandlerBuilder<D> schedule<M>({
    M Function(TransitionContext ctx) getValue,
    M value,
    Duration duration = const Duration(),
    bool periodic = false,
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String label,
    String whenLabel,
  }) {
    if (post == null && value == null) {
      throw new ArgumentError("post or value must be provided");
    }
    var messageType = TypeLiteral<M>().type;
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.schedule,
      transitionHandler: (ctx) => ctx.schedule(
        () => getValue != null ? getValue(ctx) : value,
        duration: duration,
        periodic: periodic,
      ),
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      postMessageType: messageType,
      handlerLabel: label,
    ));
    return this;
  }

  /// Indicates that state data should be updated when the transition occurs, by calling the
  /// provided [update] function.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and the
  /// update will occur only if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  TransitionHandlerBuilder<D> updateData(
    void Function(D current) update, {
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
  }) {
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.updateData,
      dataType: TypeLiteral<D>().type,
      transitionHandler: (ctx) => ctx.updateData<D>((current) => update(current)),
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      handlerLabel: label,
    ));
    return this;
  }

  /// Indicates that state data should be replaced when the transition occurs, by calling the
  /// provided [replace] function.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and the
  /// replace will occur only if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  TransitionHandlerBuilder<D> replaceData(
    D Function(D current) replace, {
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
  }) {
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.replaceData,
      dataType: TypeLiteral<D>().type,
      transitionHandler: (ctx) => ctx.replaceData<D>((current) => replace(current)),
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      handlerLabel: label,
    ));
    return this;
  }

  /// Indicates that provided [handler] function should be called when the transition occurs.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and handler
  /// is called only if the function yields `true`. This guard condition can be labeled in a DOT
  /// graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  TransitionHandlerBuilder<D> handle(
    FutureOr<void> Function(TransitionContext ctx, D data) handler, {
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
  }) {
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.opaqueHandler,
      transitionHandler: (ctx) => handler(ctx, ctx.findData<D>()),
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      handlerLabel: label,
    ));
    return this;
  }
}

/// Defines methods for building a transition handler that expects payloads of type [P] and state
/// data of type [D].
///
/// A [TransitionHandlerBuilder] is typically obtained by calling [StateBuilder.onEnter].
class EntryTransitionHandlerBuilder<D, P> extends TransitionHandlerBuilder<D> {
  final Type _payloadType = TypeLiteral<P>().type;

  EntryTransitionHandlerBuilder._(StateKey forState) : super(forState);

  /// Indicates that provided [handler] function should be called when the transition occurs.
  ///
  /// A [channel] can be provided to ensure consistent typing of the payload between the message
  /// handler where the transition is triggered, and the transition handler.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and handler
  /// is called only if the function yields `true`. This guard condition can be labeled in a DOT
  /// graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  EntryTransitionHandlerBuilder<D, P> handleWithPayload(
    FutureOr<void> Function(TransitionContext ctx, P payload) handler, {
    EntryChannel<P> channel,
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
    bool isPayloadOptional = false,
  }) {
    if (channel != null && channel.stateKey != _forState) {
      throw ArgumentError('The channel state ${channel.stateKey} does not match $_forState');
    }

    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.opaqueHandler,
      transitionHandler: (ctx) {
        return handler(ctx, _tryGetPayload<P>(ctx, channel, isPayloadOptional));
      },
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      handlerLabel: label,
    ));
    return this;
  }

  EntryTransitionHandlerBuilder<D, P> postWithPayload<M>(
    FutureOr<M> Function(TransitionContext ctx, P payload) getValue, {
    EntryChannel<P> channel,
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
    bool isPayloadOptional = false,
  }) {
    if (channel != null && channel.stateKey != _forState) {
      throw ArgumentError('The channel state ${channel.stateKey} does not match $_forState');
    }
    this.post(
      getValue: (ctx) => getValue(ctx, _tryGetPayload<P>(ctx, channel, isPayloadOptional)),
      label: label,
      when: when,
      whenLabel: whenLabel,
    );
    return this;
  }

  /// Indicates that state data should be updated when the transition occurs, by calling the
  /// provided [update] function.
  ///
  /// A [channel] can be provided to ensure consistent typing of the payload between the message
  /// handler where the transition is triggered, and the transition handler.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and the
  /// update will occur only if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  EntryTransitionHandlerBuilder<D, P> updateDataFromPayload(
    void Function(D current, P payload) update, {
    EntryChannel<P> channel,
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
    bool isPayloadOptional = false,
  }) {
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.updateData,
      dataType: TypeLiteral<D>().type,
      transitionHandler: (ctx) {
        ctx.updateData<D>((current) => update(
              current,
              _tryGetPayload<P>(ctx, channel, isPayloadOptional),
            ));
      },
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      handlerLabel: label,
    ));
    return this;
  }

  /// Indicates that state data should be replaced when the transition occurs, by calling the
  /// provided [replace] function.
  ///
  /// A [channel] can be provided to ensure consistent typing of the payload between the message
  /// handler where the transition is triggered, and the transition handler.
  ///
  /// If [when] is provided, this function will be called when the transition occurs, and the
  /// replace will occur only if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// The transition handler can be labeled in a DOT graph by providing [label].
  EntryTransitionHandlerBuilder<D, P> replaceDataFromPayload(
    D Function(D current, P payload) replace, {
    EntryChannel<P> channel,
    FutureOr<bool> Function(TransitionContext ctx, D data) when,
    String whenLabel,
    String label,
    bool isPayloadOptional = false,
  }) {
    _handlers.add(_TransitionHandlerInfo._(
      handlerType: _TransitionHandlerType.replaceData,
      dataType: TypeLiteral<D>().type,
      transitionHandler: (ctx) {
        ctx.replaceData<D>((current) => replace(
              current,
              _tryGetPayload<P>(ctx, channel, isPayloadOptional),
            ));
      },
      guard: when != null ? (ctx) => when(ctx, ctx.findData<D>()) : null,
      guardLabel: whenLabel,
      handlerLabel: label,
    ));
    return this;
  }

  P _tryGetPayload<P>(
    TransitionContext ctx,
    EntryChannel<P> channel,
    bool isPayloadOptional,
  ) {
    var payload = ctx.payload;
    P typedPayload;
    if (channel != null) {
      if (payload == null) {
        throw StateError(
            'Unable to enter state ${_forState} from ${ctx.from} through channel because no payload is available.');
      }
      if (payload is _ChannelEntry<P>) {
        if (payload.channel.stateKey != _forState) {
          throw StateError(
              'Unable to enter ${_forState} from ${ctx.from} through channel channel because the channel is for state ${payload.channel.stateKey}.');
        }
        typedPayload = payload.payload;
      } else {
        throw StateError(
            'Unable to enter ${_forState} from ${ctx.from} because payload ${payload.toString()} is ' +
                'not of expected type ${channel.runtimeType}');
      }
    } else if (ctx.payload is P) {
      typedPayload = ctx.payload as P;
    } else if (ctx.payload != null) {
      throw StateError(
          'Unable to enter ${this._forState} from ${ctx.from} because payload ${ctx.payload?.toString()} is ' +
              'not of expected type ${_payloadType}');
    } else if (ctx.payload == null) {
      throw StateError(
          'Unable to enter ${this._forState} from ${ctx.from} because because no optional payload is null.');
    }

    return typedPayload;
  }
}

class _TransitionHandlerInfo {
  final _TransitionHandlerType handlerType;
  final TransitionHandler transitionHandler;
  final FutureOr<bool> Function(TransitionContext ctx) guard;
  final String guardLabel;
  final Type dataType;
  final Type postMessageType;
  final String handlerLabel;

  _TransitionHandlerInfo._({
    @required this.handlerType,
    @required this.transitionHandler,
    @required this.guard,
    this.guardLabel,
    this.dataType,
    this.postMessageType,
    this.handlerLabel,
  });
}
