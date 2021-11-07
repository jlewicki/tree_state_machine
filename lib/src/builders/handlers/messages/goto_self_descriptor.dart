part of tree_builders;

class _GoToSelfDescriptor extends _MessageHandlerDescriptor {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.gotoSelf;
  @override
  final Type messageType;
  @override
  final MessageHandler handler;
  @override
  final List<_MessageActionInfo> actions;
  @override
  final String? label;
  @override
  final String? messageName;

  _GoToSelfDescriptor._(this.messageType, this.messageName, this.actions, this.handler, this.label);

  static _GoToSelfDescriptor createForMessage<M>(
    TransitionHandler? transitionAction,
    _MessageAction<M>? action,
    String? label,
    String? messageName,
  ) {
    return _GoToSelfDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      action != null ? [action] : [],
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var _action = action?._action ?? _emptyAction;
        return _action(msgCtx, msg)
            .bind((_) => msgCtx.goToSelf(transitionAction: transitionAction));
      },
      label,
    );
  }

  static _GoToSelfDescriptor createForMessagAndData<M, D>(
    TransitionHandler? transitionAction,
    _MessageActionWithData<M, D>? action,
    String? label,
    String? messageName,
  ) {
    return _GoToSelfDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      action != null ? [action] : [],
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var data = msgCtx.dataValueOrThrow<D>();
        var _action = action?._action ?? _emptyDataAction;
        return _action(msgCtx, msg, data)
            .bind((_) => msgCtx.goToSelf(transitionAction: transitionAction));
      },
      label,
    );
  }
}

class _ContinuationGoToSelfDescriptor<T> implements _ContinuationMessageHandlerDescriptor<T> {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.gotoSelf;
  @override
  final Type messageType;
  final _MessageActionInfo? action;
  @override
  final MessageHandler Function(T ctx) continuation;
  @override
  final String? label;
  @override
  final String? messageName;
  _ContinuationGoToSelfDescriptor._(
      this.messageType, this.messageName, this.action, this.continuation, this.label);

  @override
  List<_MessageActionInfo> get actions => action != null ? [action!] : [];

  static _ContinuationGoToSelfDescriptor<T> createForMessage<M, T>(
    TransitionHandler? transitionAction,
    _ContinuationMessageAction<M, T>? action,
    String? messageName,
    String? label,
  ) {
    return _ContinuationGoToSelfDescriptor._(
        TypeLiteral<M>().type,
        messageName,
        action,
        (ctx) => (msgCtx) {
              var msg = msgCtx.messageAsOrThrow<M>();
              var _action = action?._action ?? _emptyContinuationAction;
              return _action(msgCtx, msg, ctx)
                  .bind((_) => msgCtx.goToSelf(transitionAction: transitionAction));
            },
        label);
  }

  static _ContinuationGoToSelfDescriptor<T> createForMessageAndData<M, D, T>(
    TransitionHandler? transitionAction,
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? messageName,
    String? label,
  ) {
    return _ContinuationGoToSelfDescriptor._(
        TypeLiteral<M>().type,
        messageName,
        action,
        (ctx) => (msgCtx) {
              var msg = msgCtx.messageAsOrThrow<M>();
              var data = msgCtx.dataValueOrThrow<D>();
              var _action = action?._action ?? _emptyContinuationActionWithData;
              return _action(msgCtx, msg, data, ctx)
                  .bind((_) => msgCtx.goToSelf(transitionAction: transitionAction));
            },
        label);
  }
}
