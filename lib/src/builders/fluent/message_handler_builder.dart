part of fluent_tree_builders;

enum _MessageHandlerType {
  goto,
  gotoSelf,
  stay,
  unhandled,
  updateData,
  replaceData,
  post,
  schedule,
}

/// Defines methods for building a message handler that responds to messages of type [M].
///
/// A [MessageHandlerBuilder] is typically obtained by calling [StateBuilder.onMessage].
class MessageHandlerBuilder<M> {
  final StateKey _forState;
  final Type _messageType = TypeLiteral<M>().type;
  final List<_MessageHandlerInfo> _handlers = [];

  MessageHandlerBuilder(this._forState);

  /// Indicates that a transition to [targetState] should occur.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// transition will only occur if the function yields `true`. This guard condition can be labeled
  /// in a DOT graph by providing [whenLabel].
  ///
  /// If [before] is provided, this function will be called before the transition occurs (and
  /// after [when] returns true, if it was provided).
  ///
  /// If [payload] is provided, this function will be called to generate a value for
  /// [TransitionContext.payload] before the transition occurs.
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  ///
  /// If [reenterTarget] is true, then the target state will be re-enterd (that is, its exit and
  /// entry handlers will be called), even if the state is already active.
  MessageHandlerBuilder<M> goTo(
    StateKey targetState, {
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    TransitionHandler transitionAction,
    bool reenterTarget = false,
    FutureOr<Object> Function(M message, MessageContext ctx) payload,
    FutureOr<void> Function(M message, MessageContext ctx) before,
  }) {
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.goto,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        var payloadCont = (payloadVal) => msgCtx.goTo(
              targetState,
              reenterTarget: reenterTarget,
              transitionAction: transitionAction,
              payload: payloadVal,
            );
        FutureOr<MessageResult> Function(Object payloadVal) beforeCont = (_) {
          if (payload != null) {
            var futureOrPayload = payload(msgCtx.message as M, msgCtx);
            return futureOrPayload is Future
                ? futureOrPayload.then(payloadCont)
                : payloadCont(futureOrPayload);
          } else {
            return payloadCont(null);
          }
        };

        before = before ?? (m, c) {};
        var beforeResult = before(msgCtx.message as M, msgCtx);
        return beforeResult is Future ? beforeResult.then(beforeCont) : beforeCont(null);
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      targetState: targetState,
    ));
    return this;
  }

  /// Indicates that a [channel] should be entered, causing a transition to the state
  /// belonging to that channel.  The payload value for the channel is obtained by calling
  /// the [payload] function.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// channel will be entered only if the function yields `true`. This guard condition can be
  /// labeled in a DOT graph by providing [whenLabel].
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  ///
  /// If [reenterTarget] is true, then the target state will be re-enterd (that is, its exit and
  /// entry handlers will be called), even if the state is already active.
  MessageHandlerBuilder<M> enterChannel<P>(
    EntryChannel<P> channel, {
    @required FutureOr<P> Function(M message, MessageContext ctx) payload,
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    TransitionHandler transitionAction,
    bool reenterTarget = false,
  }) {
    return goTo(
      channel.stateKey,
      payload: (msg, ctx) {
        var withPayload = (payloadVal) => _ChannelEntry<P>(channel, payloadVal);
        var futureOrPayload = payload(ctx.message as M, ctx);
        return futureOrPayload is Future<void>
            ? (futureOrPayload as Future<void>).then(withPayload)
            : withPayload(futureOrPayload);
      },
      when: when,
      whenLabel: whenLabel,
      reenterTarget: reenterTarget,
      transitionAction: transitionAction,
    );
  }

  /// Indicates that a self-transition should occur.
  ///
  /// A self-transition means that the state is exited and re-entered, calling any exit and entry
  /// handlers for the state.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// self-transition will occur only if the function yields `true`. This guard condition can be
  /// labeled in a DOT graph by providing [whenLabel].
  ///
  /// If [before] is provided, this function will be called before the self-transition occurs (and
  /// after [when] returns true, if it was provided).
  ///
  /// If [transitionAction] is specified, this function will be called after the state is exited,
  /// and before entering.
  MessageHandlerBuilder<M> goToSelf({
    FutureOr<void> Function(M message, MessageContext ctx) before,
    TransitionHandler transitionAction,
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
  }) {
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.gotoSelf,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        var actionCont = (_) => msgCtx.goToSelf(transitionAction: transitionAction);
        before = before ?? (m, c) {};
        var beforeResult = before(msgCtx.message as M, msgCtx);
        return beforeResult is Future ? beforeResult.then(actionCont) : actionCont(null);
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      targetState: this._forState,
    ));
    return this;
  }

  /// Indicates that no state transition should occur.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// stay will occur only if the function yields `true`. This guard condition can be
  /// labeled in a DOT graph by providing [whenLabel].
  ///
  /// If [before] is provided, this function will be called before control returns to the state
  /// machine (and after [when] returns true, if it was provided).
  MessageHandlerBuilder<M> stay({
    FutureOr Function(M message, MessageContext ctx) before,
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
  }) {
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.stay,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        var actionCont = (_) => msgCtx.stay();
        before = before ?? (m, c) {};
        var beforeResult = before(msgCtx.message as M, msgCtx);
        return beforeResult is Future ? beforeResult.then(actionCont) : actionCont(null);
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
    ));
    return this;
  }

  MessageHandlerBuilder<M> replaceData<D>(
    D Function(D current, M message, MessageContext ctx) replace, {
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    bool unhandled = false,
  }) {
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.replaceData,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        var result =
            msgCtx.replaceData<D>((current) => replace(current, msgCtx.message as M, msgCtx));
        return unhandled ? msgCtx.unhandled() : result;
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      dataType: TypeLiteral<D>().type,
      isUnhandled: unhandled,
    ));
    return this;
  }

  MessageHandlerBuilder<M> updateData<D>(
    void Function(D current, M message, MessageContext ctx) update, {
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    bool unhandled = false,
  }) {
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.updateData,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        var result =
            msgCtx.updateData<D>((current) => update(current, msgCtx.message as M, msgCtx));
        return unhandled ? msgCtx.unhandled() : result;
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      dataType: TypeLiteral<D>().type,
      isUnhandled: unhandled,
    ));
    return this;
  }

  /// Indicates that a message of type [M2] should be posted to the state machine. No state
  /// transition will occur.
  ///
  /// If [getValue] is provided, this function will be called to obtain the message to post.
  /// Otherwise [value] will be posted.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// post will occur only if the function yields `true`. This guard condition can be
  /// labeled in a DOT graph by providing [whenLabel].
  MessageHandlerBuilder<M> post<M2>({
    M2 Function(MessageContext ctx) getValue,
    M2 value,
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    bool unhandled = false,
  }) {
    if (getValue != null && value != null) {
      throw ArgumentError('Both getValue and value are provided. Only provide one of them');
    } else if (getValue == null && value == null) {
      throw ArgumentError('getValue or value must be provided');
    }

    var postType = TypeLiteral<M2>().type;
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.post,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        msgCtx.post(getValue != null ? getValue(msgCtx) : value);
        return unhandled ? msgCtx.unhandled() : msgCtx.stay();
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      postMessageType: postType,
      postMessageValue: value,
      isUnhandled: unhandled,
    ));
    return this;
  }

  /// Indicates that a message of type [M2] should be scheduled to be posted to the state machine.
  /// No state transition will occur.
  ///
  /// [getMessage] will be passed to [MessageContext.schedule], and will be called to generate the
  /// messages that will be posted. Refer to the documentation for [MessageContext.schedule] for
  /// usage of the [duration] and [periodic] arguments.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// post will occur only if the function yields `true`. This guard condition can be
  /// labeled in a DOT graph by providing [whenLabel].
  MessageHandlerBuilder<M> schedule<M2>({
    M2 Function() getMessage,
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    Duration duration = const Duration(),
    bool periodic = false,
    bool unhandled = false,
  }) {
    var postType = TypeLiteral<M2>().type;
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.schedule,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        msgCtx.schedule(getMessage, duration: duration, periodic: periodic);
        return unhandled ? msgCtx.unhandled() : msgCtx.stay();
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      postMessageType: postType,
      isUnhandled: unhandled,
    ));
    return this;
  }

  /// Indicates that the [before] function should be called, and then the parent state should
  /// attempt to handle the message.
  ///
  /// In general it is not necessary to call this method, because by default a state will
  /// delegate to its parent state unless a handler is registered by calling
  /// [StateBuilder.onMessage]. But in cases where an action/side effect needs to take place
  /// before delegating to the parent, this method can be useful.
  ///
  /// If [when] is provided, this function will be called when a message is received, and the
  /// transfer of control to the parent state will only occur if the function yields `true`.
  /// This guard condition can be labeled in a DOT graph by providing [whenLabel].
  MessageHandlerBuilder<M> unhandled(
    FutureOr<void> Function(M message, MessageContext ctx) before, {
    FutureOr<bool> Function(M message, MessageContext ctx) when,
    String whenLabel,
    String beforeLabel,
  }) {
    _handlers.add(_MessageHandlerInfo._(
      handlerType: _MessageHandlerType.unhandled,
      messageType: _messageType,
      messageHandler: (msgCtx) {
        var actionCont = (_) => msgCtx.unhandled();
        before = before ?? (m, c) {};
        var beforeResult = before(msgCtx.message as M, msgCtx);
        return beforeResult is Future ? beforeResult.then(actionCont) : actionCont(null);
      },
      guard: _toTransitionGuard(when),
      guardLabel: whenLabel,
      handlerLabel: beforeLabel,
      isUnhandled: true,
    ));
    return this;
  }

  _TransitionGuard _toTransitionGuard(
    FutureOr<bool> Function(M message, MessageContext ctx) guard,
  ) {
    return guard != null ? (ctx) => guard(ctx.message as M, ctx) : null;
  }
}

typedef _TransitionGuard = FutureOr<bool> Function(MessageContext ctx);

class _MessageHandlerInfo {
  final _MessageHandlerType handlerType;
  final Type messageType;
  final MessageHandler messageHandler;
  final StateKey targetState;
  final String label;
  final FutureOr<bool> Function(MessageContext ctx) guard;
  final String guardLabel;
  final String handlerLabel;
  final Type postMessageType;
  final Object postMessageValue;
  final bool isScheduled;
  final Type dataType;
  final bool isUnhandled;

  _MessageHandlerInfo._({
    @required this.handlerType,
    @required this.messageHandler,
    @required this.messageType,
    this.guard,
    this.guardLabel,
    this.handlerLabel,
    this.targetState,
    this.label,
    this.postMessageType,
    this.postMessageValue,
    this.isScheduled,
    this.dataType,
    bool isUnhandled,
  }) : this.isUnhandled = isUnhandled ?? false;
}
