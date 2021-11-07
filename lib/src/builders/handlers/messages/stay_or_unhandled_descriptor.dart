part of tree_builders;

class _StayOrUnhandledDescriptor extends _MessageHandlerDescriptor {
  @override
  late final _MessageHandlerType handlerType;
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
  final bool handled;

  _StayOrUnhandledDescriptor._(
      this.messageType, this.messageName, this.actions, this.handled, this.handler, this.label)
      : handlerType = handled ? _MessageHandlerType.stay : _MessageHandlerType.unhandled;

  static _StayOrUnhandledDescriptor createForMessage<M>(
    StateKey stayInState,
    _MessageAction<M>? action,
    String? label,
    String? messageName, {
    required bool handled,
  }) {
    return _StayOrUnhandledDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      action != null ? [action] : [],
      handled,
      (msgCtx) {
        var _action = action?._action ?? _MessageAction._empty;
        return _action(msgCtx, msgCtx.messageAsOrThrow<M>())
            .bind((_) => handled ? msgCtx.stay() : msgCtx.unhandled());
      },
      label,
    );
  }

  static _StayOrUnhandledDescriptor createForMessageAndData<M, D>(
    StateKey stayInState,
    _MessageActionWithData<M, D>? action,
    String? label,
    String? messageName, {
    bool handled = true,
  }) {
    return _StayOrUnhandledDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      action != null ? [action] : [],
      handled,
      (msgCtx) {
        var _action = action?._action ?? _MessageActionWithData._empty;
        return _action(msgCtx, msgCtx.messageAsOrThrow<M>(), msgCtx.dataValueOrThrow<D>())
            .bind((_) => handled ? msgCtx.stay() : msgCtx.unhandled());
      },
      label,
    );
  }
}

class _ContinuationStayOrUnhandledDescriptor<T>
    implements _ContinuationMessageHandlerDescriptor<T> {
  @override
  late final _MessageHandlerType handlerType;
  @override
  final Type messageType;
  @override
  final MessageHandler Function(T ctx) continuation;
  @override
  final String? messageName;
  @override
  final String? label;
  final bool handled;

  @override
  List<_MessageActionInfo> get actions => [];

  _ContinuationStayOrUnhandledDescriptor._(
      this.messageType, this.messageName, this.handled, this.continuation, this.label)
      : handlerType = handled ? _MessageHandlerType.stay : _MessageHandlerType.unhandled;

  static _ContinuationStayOrUnhandledDescriptor<T> createForMessage<M, T>(
    StateKey stayInState,
    _ContinuationMessageAction<M, T>? action,
    String? label,
    String? messageName, {
    required bool handled,
  }) {
    return _ContinuationStayOrUnhandledDescriptor._(
      TypeLiteral<M>().runtimeType,
      messageName,
      handled,
      (ctx) => (msgCtx) {
        var _action = action?._action ?? _ContinuationMessageAction._empty;
        return _action(msgCtx, msgCtx.messageAsOrThrow<M>(), ctx)
            .bind((_) => handled ? msgCtx.stay() : msgCtx.unhandled());
      },
      label,
    );
  }

  static _ContinuationStayOrUnhandledDescriptor<T> createForMessageAndData<M, D, T>(
    StateKey stayInState,
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? label,
    String? messageName, {
    required bool handled,
  }) {
    return _ContinuationStayOrUnhandledDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      handled,
      (ctx) => (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var data = msgCtx.dataValueOrThrow<D>();
        var _action = action?._action ?? _ContinuationMessageActionWithData._empty;
        return _action(msgCtx, msg, data, ctx)
            .bind((_) => handled ? msgCtx.stay() : msgCtx.unhandled());
      },
      label,
    );
  }
}
