part of tree_builders;

class _TransitionWhenDescriptor implements _TransitionHandlerDescriptor {
  @override
  _TransitionHandlerType handlerType = _TransitionHandlerType.when;
  @override
  String? label;
  @override
  TransitionHandler _handler;
  final List<_TransitionConditionInfo> conditions;
  _TransitionWhenDescriptor._(this.conditions, this._handler, this.label);

  factory _TransitionWhenDescriptor(
    List<_TransitionCondition> conditions,
    String? label,
  ) {
    return _TransitionWhenDescriptor._(
      conditions,
      (transCtx) => _runConditions(conditions.iterator, transCtx),
      label,
    );
  }

  static _TransitionWhenDescriptor createForData<D>(
    List<_TransitionConditionWithContext<D>> conditions,
    String? label,
  ) {
    return _TransitionWhenDescriptor._(
      conditions,
      (transCtx) => _runConditionsWithContext<D>(
          conditions.iterator, transCtx, transCtx.dataValueOrThrow<D>()),
      label,
    );
  }

  static FutureOr<void> _runConditions(
    Iterator<_TransitionCondition> conditionIterator,
    TransitionContext transCtx,
  ) {
    if (conditionIterator.moveNext()) {
      var condition = conditionIterator.current;
      condition._condition(transCtx).bind((allowed) => allowed
          ? condition._whenTrueHandler._handler(transCtx)
          : _runConditions(conditionIterator, transCtx));
    }
  }

  static FutureOr<void> _runConditionsWithContext<T>(
    Iterator<_TransitionConditionWithContext<T>> conditionIterator,
    TransitionContext transCtx,
    T ctx,
  ) {
    if (conditionIterator.moveNext()) {
      var condition = conditionIterator.current;
      return condition._condition(transCtx, ctx).bind((allowed) => allowed
          ? condition._whenTrueHandler._handler(transCtx)
          : _runConditionsWithContext<T>(conditionIterator, transCtx, ctx));
    }
  }
}

class _TransitionCondition implements _TransitionConditionInfo {
  final FutureOr<bool> Function(TransitionContext ctx) _condition;
  final _TransitionHandlerDescriptor _whenTrueHandler;
  @override
  final String? label;
  _TransitionCondition(this._condition, this._whenTrueHandler, this.label);
}

class _TransitionConditionWithContext<T> implements _TransitionConditionInfo {
  final FutureOr<bool> Function(TransitionContext transCtx, T ctx) _condition;
  final _TransitionHandlerDescriptor _whenTrueHandler;
  @override
  final String? label;
  _TransitionConditionWithContext(this._condition, this._whenTrueHandler, this.label);
}
