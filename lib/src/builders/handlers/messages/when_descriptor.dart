part of tree_builders;

class _WhenDescriptor extends _MessageHandlerDescriptor {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.when;
  @override
  final Type messageType;
  @override
  final MessageHandler handler;
  final List<_MessageConditionInfo> conditions;
  @override
  final String? label;
  @override
  final String? messageName;
  _WhenDescriptor._(this.messageType, this.messageName, this.conditions, this.handler, this.label);

  @override
  List<_MessageActionInfo> get actions =>
      conditions.expand((c) => c.whenTrueDescriptor.actions).toList();

  static _WhenDescriptor createForMessage<M>(
    List<_MessageCondition<M>> conditions, {
    String? label,
    String? messageName,
  }) {
    return _WhenDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      conditions,
      (msgCtx) => _runConditions<M>(
        conditions.iterator,
        msgCtx,
        msgCtx.messageAsOrThrow<M>(),
      ),
      label,
    );
  }

  static _WhenDescriptor createForMessageAndData<M, D>(
    List<_MessageConditionWithContext<M, D>> conditions, {
    String? label,
    String? messageName,
  }) {
    return _WhenDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      conditions,
      (msgCtx) => _runConditionsWithContext<M, D>(
          conditions.iterator, msgCtx, msgCtx.messageAsOrThrow<M>(), msgCtx.dataValueOrThrow<D>()),
      label,
    );
  }

  static FutureOr<MessageResult> _runConditions<M>(
      Iterator<_MessageCondition<M>> conditionIterator, MessageContext msgCtx, M msg) {
    if (!conditionIterator.moveNext()) {
      return msgCtx.unhandled();
    }

    var condition = conditionIterator.current;
    return condition._condition(msgCtx, msgCtx.messageAsOrThrow<M>()).bind((allowed) => allowed
        ? condition.whenTrueDescriptor.handler(msgCtx)
        : _runConditions(conditionIterator, msgCtx, msg));
  }

  static FutureOr<MessageResult> _runConditionsWithContext<M, T>(
    Iterator<_MessageConditionWithContext<M, T>> conditionIterator,
    MessageContext msgCtx,
    M msg,
    T ctx,
  ) {
    if (!conditionIterator.moveNext()) {
      return msgCtx.unhandled();
    }
    var condition = conditionIterator.current;
    return condition._condition(msgCtx, msgCtx.messageAsOrThrow<M>(), ctx).bind((allowed) => allowed
        ? condition.whenTrueDescriptor.handler(msgCtx)
        : _runConditionsWithContext(conditionIterator, msgCtx, msg, ctx));
  }

  static FutureOr<MessageResult> _runConditionsWithDataContext<M, D, T>(
    Iterator<_MessageConditionWithDataAndContext<M, D, T>> conditionIterator,
    MessageContext msgCtx,
    M msg,
    D data,
    T ctx,
  ) {
    if (!conditionIterator.moveNext()) {
      return msgCtx.unhandled();
    }
    var condition = conditionIterator.current;
    return condition._condition(msgCtx, msg, data, ctx).bind((allowed) => allowed
        ? condition.whenTrueDescriptor.handler(msgCtx)
        : _runConditionsWithDataContext(conditionIterator, msgCtx, msg, data, ctx));
  }
}

class _WhenWithContextDescriptor extends _MessageHandlerDescriptor {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.whenWithContext;
  @override
  final Type messageType;
  @override
  final MessageHandler handler;
  @override
  final String? label;
  @override
  final String? messageName;
  final List<_MessageConditionInfo> conditions;
  _WhenWithContextDescriptor._(
      this.messageType, this.messageName, this.conditions, this.handler, this.label);

  @override
  List<_MessageActionInfo> get actions =>
      conditions.expand((c) => c.whenTrueDescriptor.actions).toList();

  static _WhenWithContextDescriptor createForMessage<M, T>(
    FutureOr<T> Function(MessageContext ctx, M message) context,
    List<_MessageConditionWithContext<M, T>> conditions, {
    String? label,
    String? messageName,
  }) {
    return _WhenWithContextDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      conditions,
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        return context(msgCtx, msg).bind((ctx) => _WhenDescriptor._runConditionsWithContext<M, T>(
              conditions.iterator,
              msgCtx,
              msgCtx.messageAsOrThrow<M>(),
              ctx,
            ));
      },
      label,
    );
  }

  static _WhenWithContextDescriptor createForMessageAndData<M, D, T>(
    FutureOr<T> Function(MessageContext ctx, M message, D data) context,
    List<_MessageConditionWithDataAndContext<M, D, T>> conditions, {
    String? label,
    String? messageName,
  }) {
    return _WhenWithContextDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      conditions,
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var data = msgCtx.dataValueOrThrow<D>();
        return context(msgCtx, msg, data)
            .bind((ctx) => _WhenDescriptor._runConditionsWithDataContext<M, D, T>(
                  conditions.iterator,
                  msgCtx,
                  msgCtx.messageAsOrThrow<M>(),
                  data,
                  ctx,
                ));
      },
      label,
    );
  }
}

//     String? get label;
//  _MessageHandlerDescriptor get whenTrueDescriptor;

class _WhenResultDescriptor extends _MessageHandlerDescriptor {
  @override
  final _MessageHandlerType handlerType = _MessageHandlerType.whenResult;
  @override
  final Type messageType;
  @override
  final MessageHandler handler;
  @override
  final String? label;
  @override
  final String? messageName;
  final _MessageConditionInfo successCondition;
  final Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?> errorContinuationRef;
  _WhenResultDescriptor._(this.messageType, this.messageName, this.successCondition,
      this.errorContinuationRef, this.handler, this.label);

  @override
  List<_MessageActionInfo> get actions => [];

  List<_MessageConditionInfo> get conditions => [
        successCondition,
        if (errorContinuationRef.value != null)
          _MessageConditionInfo('failure', errorContinuationRef.value!)
      ];

  static _WhenResultDescriptor createForMessage<M, T>(
    FutureOr<Result<T>> Function(MessageContext ctx, M message) _result,
    _ContinuationMessageHandlerDescriptor<T> successContinuation,
    Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?> errorContinuationRef,
    String? label,
    String? messageName,
  ) {
    var conditionLabel = label != null ? '$label success' : 'success';
    return _WhenResultDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      _MessageConditionInfo(conditionLabel, successContinuation),
      errorContinuationRef,
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        return _result(msgCtx, msg).bind((result) {
          if (result.isError) {
            var err = result.asError!;
            var asyncErr = AsyncError(err.error, err.stackTrace);
            if (errorContinuationRef.value != null) {
              var errorHandler = errorContinuationRef.value!.continuation(asyncErr);
              return errorHandler(msgCtx);
            } else {
              throw asyncErr;
            }
          }
          var successHandler = successContinuation.continuation(result.asValue!.value);
          return successHandler(msgCtx);
        });
      },
      label,
    );
  }

  static _WhenResultDescriptor createForMessageAndData<M, D, T>(
    FutureOr<Result<T>> Function(MessageContext msgCtx, M msg, D data) _result,
    _ContinuationMessageHandlerDescriptor<T> successContinuation,
    Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?> errorContinuationRef,
    String? label,
    String? messageName,
  ) {
    var conditionLabel = label != null ? '$label success' : 'success';
    return _WhenResultDescriptor._(
      TypeLiteral<M>().type,
      messageName,
      _MessageConditionInfo(conditionLabel, successContinuation),
      errorContinuationRef,
      (msgCtx) {
        var msg = msgCtx.messageAsOrThrow<M>();
        var data = msgCtx.dataValueOrThrow<D>();
        return _result(msgCtx, msg, data).bind((result) {
          if (result.isError) {
            var err = result.asError!;
            var asyncErr = AsyncError(err.error, err.stackTrace);
            if (errorContinuationRef.value != null) {
              var errorHandler = errorContinuationRef.value!.continuation(asyncErr);
              return errorHandler(msgCtx);
            } else {
              throw asyncErr;
            }
          }
          var successHandler = successContinuation.continuation(result.asValue!.value);
          return successHandler(msgCtx);
        });
      },
      label,
    );
  }
}

class _MessageConditionInfo {
  final String? label;
  final _MessageHandlerInfo whenTrueDescriptor;
  _MessageConditionInfo(this.label, this.whenTrueDescriptor);
}

class _MessageCondition<M> implements _MessageConditionInfo {
  final FutureOr<bool> Function(MessageContext msgCtx, M msg) _condition;
  @override
  final _MessageHandlerDescriptor whenTrueDescriptor;
  @override
  final String? label;
  _MessageCondition(this._condition, this.whenTrueDescriptor, this.label);
}

class _MessageConditionWithContext<M, T> implements _MessageConditionInfo {
  final FutureOr<bool> Function(MessageContext msgCtx, M msg, T ctx) _condition;
  @override
  final _MessageHandlerDescriptor whenTrueDescriptor;
  @override
  final String? label;
  _MessageConditionWithContext(this._condition, this.whenTrueDescriptor, this.label);
}

class _MessageConditionWithDataAndContext<M, D, T> implements _MessageConditionInfo {
  final FutureOr<bool> Function(MessageContext msgCtx, M msg, D data, T ctx) _condition;
  @override
  final _MessageHandlerDescriptor whenTrueDescriptor;
  @override
  final String? label;
  _MessageConditionWithDataAndContext(this._condition, this.whenTrueDescriptor, this.label);
}
