part of '../../../declarative_builders.dart';

/// Provides methods for describing how a state behaves during a transition.
///
/// A [TransitionHandlerBuilder] is provided to the build callback provided to
/// [StateBuilder.onEnter] and [StateBuilder.onExit], and is used to describe the actions to take
/// when a transition occurs within a state.
///
/// ```dart
/// void handleExit(TransitionHandlerContext ctx) => print('State exited');
///
/// var state1 = StateKey('s1');
/// var builder = StateTreeBuilder(initialChild: state1);
///
/// builder.state(state1, (b) {
///   // Post a message when the state is entered
///   b.onEnter((b) => b.post(message: MyMessage()));
///
///   // Run a function when the state is exited
///   b.onExit((b) => b.run(handleExit));
/// });
/// ```
class TransitionHandlerBuilder<D, C> {
  final StateKey _forState;
  final Logger _log;
  final FutureOr<C> Function(TransitionContext) _makeContext;
  TransitionHandlerDescriptor<C>? _descriptor;

  TransitionHandlerBuilder._(
    this._forState,
    this._log,
    this._makeContext,
  );

  /// Runs [handler] when the transition occurs.
  ///
  /// ```dart
  /// void handleEnter(TransitionHandlerContext ctx) => print('State entered');
  /// void handleExit(TransitionHandlerContext ctx) => print('State exited');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialChild: state1);
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
  void run(
    FutureOr<void> Function(TransitionHandlerContext<D, C> ctx) handler, {
    String? label,
  }) {
    _descriptor = makeRunDescriptor<D, C>(handler, _makeContext, _log, label);
  }

  /// Posts a message to be processed by the state machine when the transition occurs.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the transition occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  /// ```dart
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialChild: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Post a MyMessage message when this state is entered.
  ///   b.onEnter((b) => b.post(getMessage: (ctx) => MyMessage()));
  /// });
  /// ```
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void post<M>({
    FutureOr<M> Function(TransitionHandlerContext<D, C> ctx)? getMessage,
    M? message,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var getMessage_ = getMessage ?? (_) => message!;
    var messageName = StateBuilder._getMessageName(null, message) ??
        TypeLiteral<D>().type.toString();
    _descriptor = makePostDescriptor<D, C, M>(
      getMessage_,
      _makeContext,
      _log,
      messageName,
      label,
    );
  }

  /// Schedules a message to be processed by the state machine when the transition occurs.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the scheduling occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  ///
  /// The scheduling will be performed using [TransitionContext.schedule]. Refer to that method
  /// for further details of scheduling semantics.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void schedule<M>({
    M Function(TransitionHandlerContext<D, C> ctx)? getMessage,
    M? message,
    Duration duration = const Duration(),
    bool periodic = false,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    //var messageName = StateBuilder._getMessageName(null, message);
    var getMessage_ = getMessage ?? (_) => message!;
    var messageName = StateBuilder._getMessageName(null, message) ??
        TypeLiteral<D>().type.toString();
    _descriptor = makeScheduleDescriptor<D, C, M>(
      getMessage_,
      duration,
      periodic,
      _makeContext,
      _log,
      messageName,
      label,
    );
  }

  /// Updates the state data of the handling state when the transition occurs.
  ///
  /// ```dart
  /// class MyStateData {
  ///   int value;
  /// }
  ///
  /// var state1 = DataStateKey<MyStateData>('s1');
  /// var builder = StateTreeBuilder(initialChild: state1);
  ///
  /// builder.dataState<MyStateData>(
  ///   state1,
  ///   InitialData(() => MyStateData()),
  ///   (b) {
  ///     // Update state data when state1 is entered.
  ///     b.onEnter((b) => b.updateOwnData((ctx) => ctx.data..value += 1)));
  ///   },
  /// });
  /// ```
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void updateOwnData(
    D Function(TransitionHandlerContext<D, C> ctx) update, {
    String? label,
  }) {
    _descriptor =
        makeUpdateDataDescriptor(update, _makeContext, _forState, _log, label);
  }

  /// Updates ancestor state data of type [D2] when the transition occurs.
  ///
  /// ```dart
  /// class MyStateData {
  ///   int value;
  /// }
  ///
  /// var state1 = DataStateKey<MyStateData>('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialChild: state1);
  ///
  /// builder.dataState<MyStateData>(
  ///   state1,
  ///   InitialData(() => MyStateData()),
  ///   emptyState,
  ///   initialChild: InitialChild(state2)
  /// });
  ///
  /// builder.state(state2, (b) {
  ///   // Update state data in ancestor state
  ///   b.onEnter((b) => b.updateData<MyStateData>((ctx) => ctx.data..value += 1)));
  /// }, parent: state1);
  /// ```
  ///
  /// If more than one ancestor data state share the same state data type of [D2], [stateToUpdate]
  /// can be provided to specify which state data should be updated.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  void updateData<D2>(
    D2 Function(TransitionHandlerContext<D2, C> ctx) update, {
    DataStateKey<D2>? stateToUpdate,
    String? label,
  }) {
    _descriptor =
        makeUpdateDataDescriptor(update, _makeContext, _forState, _log, label);
  }

  /// Describes transition behavior that may be run conditionally.
  ///
  /// When the transition occurs, the [condition] function is evaluated. If the function returns
  /// `true`, the behavior described by the [buildTrue] callback will take place.
  ///
  /// The returned [TransitionHandlerWhenBuilder] may be used to define additional conditional
  /// behavior, including a fallback [TransitionHandlerWhenBuilder.otherwise] condition.
  ///
  /// ```dart
  /// class MyStateData {
  ///   int value = 0;
  /// }
  /// class Payload {
  ///   string op = '';
  /// }
  ///
  /// var state1 = DataStateKey<MyStateData>('s1');
  /// var payloadChannel = Channel<Payload>(state1);
  /// var builder = StateTreeBuilder(initialChild: state1);
  ///
  /// builder.dataState<MyStateData>(
  ///   state1,
  ///   InitialData(() => MyStateData()),
  ///   (b) => b.onEnterFromChannel<Payload>(payloadChannel, (transBuilder) {
  ///     transBuilder
  ///         .when(
  ///           // The payload value is available in ctx.context
  ///           (ctx) => ctx.context.op == 'add',
  ///           (b) => b.updateOwnData((ctx) => ctx.data..value += 1),
  ///         )
  ///         .when(
  ///           (ctx) => ctx.context.op == 'subtract',
  ///           (b) => b.updateOwnData((ctx) => ctx.data..value -= 1),
  ///         )
  ///         .otherwise(
  ///           (b) => b.updateOwnData((ctx) => ctx.data..value = 0),
  ///         );
  ///   }),
  /// );
  /// ```
  ///
  /// If more than one condition is defined, the conditions are evaluated in the order they are
  /// defined by calls to [TransitionHandlerWhenBuilder.when].
  TransitionHandlerWhenBuilder<D, C> when(
    FutureOr<bool> Function(TransitionHandlerContext<D, C> ctx) condition,
    void Function(TransitionHandlerBuilder<D, C> builder) buildTrue, {
    String? label,
  }) {
    var conditions = <TransitionConditionDescriptor<C>>[];
    var whenBuilder = TransitionHandlerWhenBuilder<D, C>._(
      conditions,
      () => TransitionHandlerBuilder<D, C>._(_forState, _log, _makeContext),
    );

    whenBuilder.when(condition, buildTrue, label: label);
    _descriptor =
        makeWhenTransitionDescriptor(conditions, _makeContext, _log, label);
    return whenBuilder;
  }

  /// Describes transition behavior that may be run conditionally, sharing a context value among
  /// conditions.
  ///
  /// This method is similar to [when], but a [context] function providing a contextual value is
  /// first called before evaluating any conditions. The context value can be accessed by the
  /// conditions with the [TransitionHandlerContext.context] property. This may be useful in
  /// avoiding generating the context value repeatedly in each condition.
  ///
  /// When the transition occurs, the [condition] function is evaluated. If the function returns
  /// `true`, the behavior described by the [buildTrue] callback will take place.
  ///
  /// The returned [TransitionHandlerWhenBuilder] may be used to define additional conditional
  /// behavior, including a fallback [TransitionHandlerWhenBuilder.otherwise] condition.
  ///
  /// If more than one condition is defined, the conditions are evaluated in the order they are
  /// defined by calls to [TransitionHandlerWhenBuilder.when].
  TransitionHandlerWhenBuilder<D, C2> whenWith<C2>(
    FutureOr<C2> Function(TransitionHandlerContext<D, C> ctx) context,
    FutureOr<bool> Function(TransitionHandlerContext<D, C2> ctx) condition,
    void Function(TransitionHandlerBuilder<D, C2> builder) buildTrueHandler, {
    String? label,
  }) {
    var contextRef = Ref<C2?>(null);
    var conditions = <TransitionConditionDescriptor<C2>>[];
    var whenBuilder = TransitionHandlerWhenBuilder<D, C2>._(
      conditions,
      () => TransitionHandlerBuilder<D, C2>._(
          _forState, _log, (_) => contextRef.value!),
    );

    whenBuilder.when(condition, buildTrueHandler, label: label);
    _descriptor = makeWhenWithContextDescriptor<D, C, C2>(
      context,
      conditions,
      _makeContext,
      _log,
      label,
    );
    return whenBuilder;
  }

  /// Describes transition behavior that runs conditionally, depending on a [Result] value.
  ///
  /// When the transition occurs, the [result] function is evaluated, and the returned [Result] is
  /// used to determine the transition behavior. If [Result.isValue] is `true`, then the behavior
  /// described by the [buildSuccess] callback will take place. If [Result.isError] is true, then
  /// an exception will be raised. However, [TransitionHandlerWhenResultBuilder.otherwise] can be
  /// used to override the default error handling.
  TransitionHandlerWhenResultBuilder<D> whenResult<T>(
    FutureOr<Result<T>> Function(TransitionHandlerContext<D, C> ctx) result,
    void Function(TransitionHandlerBuilder<D, T> builder) buildSuccess, {
    String? label,
  }) {
    var resultRef = Ref<Result<T>?>(null);
    var successBuilder = TransitionHandlerBuilder<D, T>._(
        _forState,
        _log,
        // This will only be called when the result is succesful, so this crazy property path will be
        // valid.
        (_) => resultRef.value!.asValue!.value);
    var failureBuilder =
        TransitionHandlerBuilder<D, AsyncError>._(_forState, _log, (_) {
      var err = resultRef.value!.asError!;
      return AsyncError(err.error, err.stackTrace);
    });

    buildSuccess(successBuilder);
    var successDesr = successBuilder._descriptor;
    if (successDesr == null) {
      throw StateError(
          'No success handler was defined for whenResult. Make sure to define the success '
          'handler in the buildSuccessHandler function.');
    }

    var failureDescrRef = Ref<TransitionHandlerDescriptor<AsyncError>?>(null);
    _descriptor = makeWhenResultTransitionDescriptor<C, D, T>(
      _forState,
      result,
      _makeContext,
      resultRef,
      successDesr,
      failureDescrRef,
      _log,
      label,
    );
    return TransitionHandlerWhenResultBuilder<D>(
        () => failureBuilder, failureDescrRef);
  }
}

/// Provides methods for defining conditional transition behavior for a state carrying state data
/// of type [D], and a context value of type [C].
class TransitionHandlerWhenBuilder<D, C> {
  final List<TransitionConditionDescriptor<C>> _conditions;
  final TransitionHandlerBuilder<D, C> Function() _makeBuilder;
  TransitionHandlerWhenBuilder._(this._conditions, this._makeBuilder);

  /// Adds a conditional transition behavior, in the same manner as [TransitionHandlerBuilder.when].
  TransitionHandlerWhenBuilder<D, C> when(
    FutureOr<bool> Function(TransitionHandlerContext<D, C> ctx) condition,
    void Function(TransitionHandlerBuilder<D, C> builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = _makeBuilder();
    buildTrueHandler(trueBuilder);

    var whenTrueDescr = trueBuilder._descriptor;
    if (whenTrueDescr != null) {
      var conditionInfo = TransitionConditionInfo(label, whenTrueDescr.info);
      _conditions.add(
        TransitionConditionDescriptor.withData<D, C>(
          conditionInfo,
          condition,
          whenTrueDescr,
        ),
      );
    }
    return this;
  }

  /// Adds a transition behavior that will take place if no other conditions evaluate to `true`.
  ///
  /// The [buildOtherwise] callback is used to define the behavior that should take place.
  void otherwise(
    void Function(TransitionHandlerBuilder<D, C> builder) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = _makeBuilder();
    buildOtherwise(otherwiseBuilder);

    var otherwiseDescr = otherwiseBuilder._descriptor;
    if (otherwiseDescr != null) {
      var conditionInfo = TransitionConditionInfo(label, otherwiseDescr.info);
      _conditions.add(
        TransitionConditionDescriptor<C>(
          conditionInfo,
          (_) => (_) => true,
          otherwiseDescr,
        ),
      );
    }
  }
}

/// Provides methods for error handling behavior for a state carrying state data
/// of type [D], when a [Result] is an error value.
class TransitionHandlerWhenResultBuilder<D> {
  final Ref<TransitionHandlerDescriptor<AsyncError>?> _failureDescrRef;
  final TransitionHandlerBuilder<D, AsyncError> Function() _makeErrorBuilder;

  TransitionHandlerWhenResultBuilder(
      this._makeErrorBuilder, this._failureDescrRef);

  /// Adds a transition behavior that will take place when [Result.isError] is `true`.
  ///
  /// The [buildError] callback is used to define the behavior that should take place.
  void otherwise(
    void Function(TransitionHandlerBuilder<D, AsyncError> builder) buildError, {
    String? label,
  }) {
    var errorBuilder = _makeErrorBuilder();
    buildError(errorBuilder);
    _failureDescrRef.value = errorBuilder._descriptor;
  }
}
