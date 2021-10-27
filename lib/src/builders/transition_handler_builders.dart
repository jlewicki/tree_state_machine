part of tree_builders;

class TransitionHandlerBuilder {
  final StateKey _forState;
  _TransitionHandlerDescriptor? _handler;

  TransitionHandlerBuilder._(this._forState);

  void run(TransitionHandler handler, {String? label}) {
    _handler = _TransitionHandlerDescriptor.run(handler, label);
  }

  void updateData<D>(D Function(TransitionContext transCtx, D current) update, {String? label}) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(update, label);
  }

  void post<M>({
    M Function(TransitionContext ctx)? getValue,
    M? value,
    String? label,
  }) {
    if (getValue == null && value == null) {
      throw ArgumentError('getValue or value must be provided');
    } else if (getValue != null && value != null) {
      throw ArgumentError('One of getValue or value must be provided');
    }
    var _getValue = getValue ?? (_) => value!;
    _handler = _TransitionHandlerDescriptor.post<M>(_getValue, label);
  }

  void schedule<M>({
    M Function(TransitionContext ctx)? getValue,
    M? value,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    if (getValue == null && value == null) {
      throw ArgumentError('getValue or value must be provided');
    } else if (getValue != null && value != null) {
      throw ArgumentError('One of getValue or value must be provided');
    }
    var _getValue = getValue ?? (_) => value!;
    _handler = _TransitionHandlerDescriptor.schedule<M>(_getValue, duration, periodic, label);
  }

  TransitionHandlerWhenBuilder when(
    FutureOr<bool> Function(TransitionContext msgCtx) condition,
    void Function(TransitionHandlerBuilder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = TransitionHandlerBuilder._(_forState);
    buildTrueHandler(trueBuilder);
    var conditions = [_TransitionCondition(condition, trueBuilder._handler!, label)];
    _handler = _TransitionWhenDescriptor(conditions, label);
    return TransitionHandlerWhenBuilder(_forState, conditions);
  }
}

class TransitionHandlerBuilderWithData<D> {
  final StateKey _forState;
  _TransitionHandlerDescriptor? _handler;
  TransitionHandlerBuilderWithData._(this._forState);

  void run(FutureOr<void> Function(TransitionContext ctx, D data) handler, {String? label}) {
    _handler = _TransitionHandlerDescriptor.run(
      (transCtx) => handler(transCtx, transCtx.dataValueOrThrow<D>()),
      label,
    );
  }

  void updateData(D Function(TransitionContext transCtx, D current) update, {String? label}) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(update, label);
  }

  void post<M>({
    M Function(TransitionContext ctx, D data)? getValue,
    M? value,
    String? label,
  }) {
    _handler = _postWithContext<M, D>(
      (transCtx) => transCtx.dataValueOrThrow<D>(),
      getValue,
      value,
      label,
    );
  }

  void schedule<M>({
    M Function(TransitionContext ctx, D data)? getValue,
    M? value,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    _handler = _scheduleWithContext<M, D>(
      (transCtx) => transCtx.dataValueOrThrow<D>(),
      getValue,
      value,
      duration,
      periodic,
      label,
    );
  }

  TransitionHandlerWhenWithDataBuilder<D> when(
    FutureOr<bool> Function(TransitionContext msgCtx, D data) condition,
    void Function(TransitionHandlerBuilderWithData<D>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = TransitionHandlerBuilderWithData<D>._(_forState);
    buildTrueHandler(trueBuilder);
    var conditions = [_TransitionConditionWithContext<D>(condition, trueBuilder._handler!, label)];
    _handler = _TransitionWhenDescriptor.createForData(conditions, label);
    return TransitionHandlerWhenWithDataBuilder<D>(_forState, conditions);
  }
}

class TransitionHandlerBuilderWithPayload<P> {
  _TransitionHandlerDescriptor? _handler;
  TransitionHandlerBuilderWithPayload._();

  void run(FutureOr<void> Function(TransitionContext ctx, P payload) handler, {String? label}) {
    _handler = _TransitionHandlerDescriptor.run(
      (transCtx) => handler(transCtx, transCtx.payloadOrThrow<P>()),
      label,
    );
  }

  void updateData<D>(D Function(TransitionContext transCtx, D current, P payload) update,
      {String? label}) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(
      (transCtx, current) => update(transCtx, current, transCtx.payloadOrThrow()<P>()),
      label,
    );
  }

  void post<M>({
    M Function(TransitionContext ctx, P payload)? getValue,
    M? value,
    String? label,
  }) {
    _handler = _postWithContext<M, P>(
      (transCtx) => transCtx.payloadOrThrow<P>(),
      getValue,
      value,
      label,
    );
  }

  void schedule<M>({
    M Function(TransitionContext ctx, P data)? getValue,
    M? value,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    _handler = _scheduleWithContext<M, P>(
      (transCtx) => transCtx.payloadOrThrow<P>(),
      getValue,
      value,
      duration,
      periodic,
      label,
    );
  }
}

class TransitionHandlerBuilderWithDataAndPayload<D, P> {
  _TransitionHandlerDescriptor? _handler;
  TransitionHandlerBuilderWithDataAndPayload._();

  void run(FutureOr<void> Function(TransitionContext ctx, D data, P payload) handler,
      {String? label}) {
    _handler = _TransitionHandlerDescriptor.run(
      (transCtx) => handler(transCtx, transCtx.dataValueOrThrow<D>(), transCtx.payloadOrThrow<P>()),
      label,
    );
  }

  void updateData(D Function(TransitionContext transCtx, D current, P payload) update,
      {String? label}) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(
      (transCtx, current) => update(transCtx, current, transCtx.payloadOrThrow<P>()),
      label,
    );
  }

  void post<M>({
    M Function(TransitionContext ctx, D data, P payload)? getValue,
    M? value,
    String? label,
  }) {
    if (getValue == null && value == null) {
      throw ArgumentError('getValue or value must be provided');
    } else if (getValue != null && value != null) {
      throw ArgumentError('One of getValue or value must be provided');
    }
    var _getValue = getValue ?? (_) => value!;
    _handler = _TransitionHandlerDescriptor.post<M>(
      (transCtx) {
        return _getValue(transCtx, transCtx.dataValueOrThrow<D>(), transCtx.payloadOrThrow<P>());
      },
      label,
    );
  }

  void schedule<M>({
    M Function(TransitionContext ctx, D data, P payload)? getValue,
    M? value,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    if (getValue == null && value == null) {
      throw ArgumentError('getValue or value must be provided');
    } else if (getValue != null && value != null) {
      throw ArgumentError('One of getValue or value must be provided');
    }
    var _getValue = getValue ?? (_) => value!;
    _handler = _TransitionHandlerDescriptor.schedule<M>(
      (transCtx) {
        return _getValue(transCtx, transCtx.dataValueOrThrow<D>(), transCtx.payloadOrThrow<P>());
      },
      duration,
      periodic,
      label,
    );
  }

  // TransitionHandlerWhenWithDataBuilder<D> when(
  //   FutureOr<bool> Function(TransitionContext msgCtx, D data) condition,
  //   void Function(TransitionHandlerBuilderWithData<D>) buildTrueHandler, {
  //   String? label,
  // }) {
  //   var trueBuilder = TransitionHandlerBuilderWithData<D>._(_forState);
  //   buildTrueHandler(trueBuilder);
  //   var conditions = [_TransitionConditionWithContext<D>(condition, trueBuilder._handler!, label)];
  //   _handler = _TransitionWhenDescriptor.createForData(conditions, label);
  //   return TransitionHandlerWhenWithDataBuilder<D>(_forState, conditions);
  // }
}

class TransitionHandlerWhenBuilder {
  final StateKey _forState;
  final List<_TransitionCondition> _conditions;
  TransitionHandlerWhenBuilder(this._forState, this._conditions);

  TransitionHandlerWhenBuilder when(
    FutureOr<bool> Function(TransitionContext msgCtx) condition,
    void Function(TransitionHandlerBuilder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = TransitionHandlerBuilder._(_forState);
    buildTrueHandler(trueBuilder);
    _conditions.add(_TransitionCondition(condition, trueBuilder._handler!, label));
    return this;
  }

  void otherwise(
    void Function(TransitionHandlerBuilder) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = TransitionHandlerBuilder._(_forState);
    buildOtherwise(otherwiseBuilder);
    _conditions.add(_TransitionCondition((_) => true, otherwiseBuilder._handler!, label));
  }
}

class TransitionHandlerWhenWithDataBuilder<D> {
  final StateKey _forState;
  final List<_TransitionConditionWithContext<D>> _conditions;
  TransitionHandlerWhenWithDataBuilder(this._forState, this._conditions);

  TransitionHandlerWhenWithDataBuilder<D> when(
    FutureOr<bool> Function(TransitionContext msgCtx, D data) condition,
    void Function(TransitionHandlerBuilderWithData<D>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = TransitionHandlerBuilderWithData<D>._(_forState);
    buildTrueHandler(trueBuilder);
    _conditions.add(_TransitionConditionWithContext(
      condition,
      trueBuilder._handler!,
      label,
    ));
    return this;
  }

  void otherwise(
    void Function(TransitionHandlerBuilderWithData<D>) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = TransitionHandlerBuilderWithData<D>._(_forState);
    buildOtherwise(otherwiseBuilder);
    _conditions.add(_TransitionConditionWithContext(
      (_, __) => true,
      otherwiseBuilder._handler!,
      label,
    ));
  }
}

abstract class _TransitionConditionInfo {
  String? get label;
}

_TransitionHandlerDescriptor _scheduleWithContext<M, T>(
  T Function(TransitionContext) getContext,
  M Function(TransitionContext, T)? getValue,
  M? value,
  Duration duration,
  bool periodic,
  String? label,
) {
  if (getValue == null && value == null) {
    throw ArgumentError('getValue or value must be provided');
  } else if (getValue != null && value != null) {
    throw ArgumentError('One of getValue or value must be provided');
  }
  var _getValue = getValue ?? (_, __) => value!;
  return _TransitionHandlerDescriptor.schedule<M>(
    (transCtx) => _getValue(transCtx, getContext(transCtx)),
    duration,
    periodic,
    label,
  );
}

_TransitionHandlerDescriptor _postWithContext<M, T>(
  T Function(TransitionContext) getContext,
  M Function(TransitionContext, T)? getValue,
  M? value,
  String? label,
) {
  if (getValue == null && value == null) {
    throw ArgumentError('getValue or value must be provided');
  } else if (getValue != null && value != null) {
    throw ArgumentError('One of getValue or value must be provided');
  }
  var _getValue = getValue ?? (_) => value!;
  return _TransitionHandlerDescriptor.post<M>(
    (transCtx) => _getValue(transCtx, getContext(transCtx)),
    label,
  );
}
