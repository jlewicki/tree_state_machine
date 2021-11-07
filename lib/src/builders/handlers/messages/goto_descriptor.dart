part of tree_builders;

class _GoToDescriptor extends _MessageHandlerDescriptor implements _GoToInfo {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.goto;
  @override
  final Type messageType;
  @override
  final String? label;
  @override
  final String? messageName;
  @override
  final List<_MessageActionInfo> actions;
  @override
  final MessageHandler handler;
  @override
  final StateKey targetState;

  _GoToDescriptor._(
      this.messageType, this.messageName, this.targetState, this.handler, this.actions, this.label);

  static _GoToDescriptor createForMessage<M>(
    StateKey targetState,
    TransitionHandler? transitionAction,
    bool reenterTarget,
    FutureOr<Object?> Function(MessageContext msgCtx, M msg)? payload,
    _MessageAction<M>? action,
    String? label,
    String? messageName,
  ) {
    return _GoToDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      targetState,
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var _action = action?._action ?? _MessageAction._empty;
        var _payload = payload ?? _emptyPayload;
        return _action(msgCtx, msg).bind((_) => _payload(msgCtx, msg).bind((p) => msgCtx.goTo(
            targetState,
            payload: p,
            transitionAction: transitionAction,
            reenterTarget: reenterTarget)));
      },
      action != null ? [action] : [],
      label,
    );
  }

  static _GoToDescriptor createForMessageAndData<M, D>(
    StateKey targetState,
    TransitionHandler? transitionAction,
    bool reenterTarget,
    FutureOr<Object?> Function(MessageContext msgCtx, M msg, D data)? payload,
    _MessageActionWithData<M, D>? action,
    String? label,
    String? messageName,
  ) {
    return _GoToDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      targetState,
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var data = msgCtx.dataValueOrThrow<D>();
        var _action = action?._action ?? _MessageActionWithData._empty;
        var _payload = payload ?? _emptyDataPayload;
        return _action(msgCtx, msg, data).bind((_) => _payload(msgCtx, msg, data).bind((p) =>
            msgCtx.goTo(targetState,
                payload: p, transitionAction: transitionAction, reenterTarget: reenterTarget)));
      },
      action != null ? [action] : [],
      label,
    );
  }
}

class _ContinuationGoToDescriptor<T>
    implements _ContinuationMessageHandlerDescriptor<T>, _GoToInfo {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.goto;
  @override
  final Type messageType;
  @override
  final StateKey targetState;
  @override
  final MessageHandler Function(T ctx) continuation;
  @override
  final List<_MessageActionInfo> actions = [];
  @override
  final String? messageName;
  @override
  final String? label;
  _ContinuationGoToDescriptor._(
      this.messageType, this.messageName, this.targetState, this.continuation, this.label);

  static _ContinuationGoToDescriptor<T> createForMessage<M, T>(
    StateKey targetState,
    TransitionHandler? transitionAction,
    bool reenterTarget,
    FutureOr<Object?> Function(MessageContext msgCtx, M msg, T ctx)? payload,
    _ContinuationMessageAction<M, T>? action,
    String? messageName,
    String? label,
  ) {
    return _ContinuationGoToDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      targetState,
      (ctx) => (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var _action = action?._action ?? _ContinuationMessageAction._empty;
        var _payload = payload ?? _emptyContinuationPayload;
        return _action(msgCtx, msg, ctx)
            .bind((_) => _payload(msgCtx, msg, ctx).bind((p) => msgCtx.goTo(
                  targetState,
                  payload: p,
                  transitionAction: transitionAction,
                  reenterTarget: reenterTarget,
                )));
      },
      label,
    );
  }

  static _ContinuationGoToDescriptor<T> createForMessageAndData<M, D, T>(
    StateKey targetState,
    TransitionHandler? transitionAction,
    bool reenterTarget,
    FutureOr<Object?> Function(MessageContext msgCtx, M msg, D data, T ctx)? payload,
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? label,
    String? messageName, {
    bool throwIfNull = true,
  }) {
    return _ContinuationGoToDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      targetState,
      (ctx) => (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var data = throwIfNull ? msgCtx.dataValueOrThrow<D>() : msgCtx.dataValueOrThrow<D>();
        var _action = action?._action ?? _ContinuationMessageActionWithData._empty;
        var _payload = payload ?? _emptyContinuationWithDataPayload;
        return _action(msgCtx, msg, data, ctx)
            .bind((_) => _payload(msgCtx, msg, data, ctx).bind((p) => msgCtx.goTo(
                  targetState,
                  payload: p,
                  transitionAction: transitionAction,
                  reenterTarget: reenterTarget,
                )));
      },
      label,
    );
  }
}
