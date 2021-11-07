part of tree_builders;

/// Provides methods for describing how a state behaves during a transition.
///
/// A [TransitionHandlerBuilder] is provided to the build callback provided to
/// [StateBuilder.onEnter] and [StateBuilder.onExit], and is used to describe the actions to take
/// when a transition occurs within a state.
/// ```dart
/// void handleExit(TransactionContext ctx) => print('State exited');
///
/// var state1 = StateKey('s1');
/// var builder = StateTreeBuilder(initialState: state1);
///
/// builder.state(state1, (b) {
///   // Post a message when the state is entered
///   b.onEnter((b) => b.post(message: MyMessage()));
///
///   // Run a function when the state is exited
///   b.onExit((b) => b.run(handleExit));
/// });
/// ```
class TransitionHandlerBuilder {
  final StateKey _forState;
  _TransitionHandlerDescriptor? _handler;

  TransitionHandlerBuilder._(this._forState);

  /// Runs [handler] when the transition occurs.
  ///
  /// ```dart
  /// void handleEnter(TransactionContext ctx) => print('State entered');
  /// void handleExit(TransactionContext ctx) => print('State exited');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Run a function when the state is entered
  ///   b.onEnter((b) => b.run(handleEnter));
  ///
  ///   // Run a function when the state is exited
  ///   b.onExit((b) => b.run(handleExit));
  /// });
  /// ```
  /// The handler can be labeled when formatting a state tree by providing a [label].
  void run(TransitionHandler handler, {String? label}) {
    _handler = _TransitionHandlerDescriptor.run(handler, label);
  }

  /// Updates state data of type [D] when the transition occurs.
  ///
  /// ```dart
  /// class MyStateData {
  ///   int value;
  /// }
  ///
  /// var state1 = StateKey('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.dataState<MyStateData>(
  ///   state1,
  ///   InitialData(() => MyStateData()),
  ///   emptyDataState,
  ///   initialChild: InitialChild(state2)
  /// });
  ///
  /// builder.state(state2, (b) {
  ///   // Update state data in ancestor state
  ///   b.onEnter((b) => b.updateData<MyStateData>((_, data) => data..value += 1)));
  /// }, parent: state1);
  /// ```
  ///
  /// If more than one ancestor data state share the same state data type of [D], [forState] can be
  /// provided to specify which state data should be updated.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void updateData<D>(
    D Function(TransitionContext transCtx, D current) update, {
    StateKey? forState,
    String? label,
  }) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(update, forState, label);
  }

  /// Posts a message to be processed by the state machine when a transition occurs.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the transition occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  ///
  /// ```dart
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Post a MyMessage message when this state is entered.
  ///   b.onEnter((b) => b.post(getMessage: (transCtx) => MyMessage()));
  /// });
  /// ```
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void post<M>({
    M Function(TransitionContext ctx)? getMessage,
    M? message,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getValue = getMessage ?? (_) => message!;
    _handler = _TransitionHandlerDescriptor.post<M>(_getValue, label);
  }

  /// Schedules a message to be processed by the state machine when a transition occurs.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the scheduling occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  ///
  /// The scheduling will be performed using [TransitionContext.schedule]. Refer to that method
  /// for further details of scheduling semantics.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void schedule<M>({
    M Function(TransitionContext ctx)? getMessage,
    M? message,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getValue or value must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getValue or value must be provided');
    }
    // TODO: what if we schedule on exit? How to cancel a periodic timer?
    var _getValue = getMessage ?? (_) => message!;
    _handler = _TransitionHandlerDescriptor.schedule<M>(_getValue, duration, periodic, label);
  }

  /// Indicates that a transition action should conditionally occur.
  ///
  /// When the transition occurs, [condition] will be evaluated. If `true` is returned, the
  /// transition actions defined by the [buildTrueHandler] callback will be invoked.
  ///
  /// This method returns a builder that can be used to define additional conditions, including an
  /// `otherwise` callback that can be used to define the transition behavior when none of the
  /// conditions evaluate to `true`.
  ///
  /// ```dart
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   b.onEnter((b) {
  ///     // Conditionally run an action when the state is entered.
  ///     b.when(
  ///       (transCtx) => false,
  ///       (b) => b.run((transCtx) => print('Condition 1 is true'))
  ///     ).when(
  ///       (transCtx) => true,
  ///       (b) => b.run((transCtx) => print('Condition 2 is true'))
  ///     ).otherwise(
  ///       (b) => b.run((transCtx) => print('No conditions are true'))
  ///     );
  ///   });
  /// });
  /// ```
  ///
  /// The condition can be labeled when formatting a state tree by providing a [label].
  TransitionHandlerWhenBuilder when(
    FutureOr<bool> Function(TransitionContext transCtx) condition,
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

  void run(FutureOr<void> Function(TransitionContext transCtx, D data) handler, {String? label}) {
    _handler = _TransitionHandlerDescriptor.run(
      (transCtx) => handler(transCtx, transCtx.dataValueOrThrow<D>()),
      label,
    );
  }

  void updateData(
    D Function(TransitionContext transCtx, D current) update, {
    StateKey? forState,
    String? label,
  }) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(update, forState, label);
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

  void updateData<D>(
    D Function(TransitionContext transCtx, D current, P payload) update, {
    StateKey? forState,
    String? label,
  }) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(
      (transCtx, current) => update(transCtx, current, transCtx.payloadOrThrow<P>()),
      forState,
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

  void updateData(
    D Function(TransitionContext transCtx, D current, P payload) update, {
    StateKey? forState,
    String? label,
  }) {
    _handler = _TransitionHandlerDescriptor.updateData<D>(
      (transCtx, current) => update(transCtx, current, transCtx.payloadOrThrow<P>()),
      forState,
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
    _handler = _TransitionHandlerDescriptor.post<M>(
      (transCtx) {
        return getValue != null
            ? getValue(transCtx, transCtx.dataValueOrThrow<D>(), transCtx.payloadOrThrow<P>())
            : value!;
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
    _handler = _TransitionHandlerDescriptor.schedule<M>(
      (transCtx) {
        return getValue != null
            ? getValue(transCtx, transCtx.dataValueOrThrow<D>(), transCtx.payloadOrThrow<P>())
            : value!;
      },
      duration,
      periodic,
      label,
    );
  }
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
  return _TransitionHandlerDescriptor.post<M>(
    (transCtx) => getValue != null ? getValue(transCtx, getContext(transCtx)) : value!,
    label,
  );
}
