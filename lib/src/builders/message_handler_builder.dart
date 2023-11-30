part of tree_builders;

/// Describes the message processing result of runnin an action with [MessageHandlerBuilder.action].
enum ActionResult {
  /// The message was handled, and the state machine should stay in the current state.
  handled,

  /// The message was unhandled, and should be dispatched to a parent state for processing.
  unhandled,
}

abstract class _MessageHandlerDescriptorProvider<C> {
  MessageHandlerDescriptor<C>? get descriptor;
}

class _MessageHandlerBuilder<M, D, C> implements _MessageHandlerDescriptorProvider<C> {
  final StateKey _forState;
  final FutureOr<C> Function(MessageContext) _makeContext;
  final Logger _log;
  final String? _messageName;
  @override
  MessageHandlerDescriptor<C>? descriptor;

  _MessageHandlerBuilder(this._forState, this._makeContext, this._log, this._messageName);

  /// A [MessageActionBuilder] that can be used to specify actions that should take place when
  /// handling messages.
  ///
  /// ```dart
  /// class MyMessage {}
  /// var state1 = StateKey('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialState: state1);
  /// builder.state(state1, (b) {
  ///   b.onMessage<MyMessage>((b) => b.goTo(
  ///     state2,
  ///     // Perform an action before state transition occurs.
  ///     action: b.act.run((ctx) =>
  ///       print('Going to $state2 in response to message ${ctx.message}')));
  /// });
  late final act = MessageActionBuilder<M, D, C>(_forState, _log);
}

mixin _GoToHandlerBuilderMixin<M, D, C> on _MessageHandlerBuilder<M, D, C> {
  /// Indicates that a transition to [targetState] should occur.
  ///
  /// If [action] is provided, this action will be invoked before the transition occurs. The
  /// [MessageHandlerBuilder.act] builder can be used to specify this action.
  ///
  /// If [payload] is provided, this function will be called to generate a value for
  /// [TransitionContext.payload] before the transition occurs.
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  ///
  /// If [reenterTarget] is true, then the target state will be re-entered (that is, its exit and
  /// entry handlers will be called), even if the state is already active.
  ///
  /// The state transition can be labeled when formatting a state tree by providing a [label].
  void goTo(
    StateKey targetState, {
    TransitionHandler? transitionAction,
    FutureOr<Object?> Function(MessageHandlerContext<M, D, C> ctx)? payload,
    MessageActionDescriptor<M, D, C>? action,
    bool reenterTarget = false,
    String? label,
  }) {
    descriptor = makeGoToDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      targetState,
      transitionAction,
      reenterTarget,
      payload,
      action,
      label,
      _messageName,
    );
  }

  /// Indicates that [channel] should be entered and a transition to the channels state should
  /// occur.
  ///
  /// The [payload] function wull be called to obtain the payload for the channel when the
  /// transition occurs.
  ///
  /// If [action] is provided, this action will be invoked before the transition occurs. The
  /// [MessageHandlerBuilder.act] builder can be used to specify this action.
  ///
  /// If [reenterTarget] is true, then the target state will be re-entered (that is, its exit and
  /// entry handlers will be called), even if the state is already active.
  void enterChannel<P>(
    Channel<P> channel,
    FutureOr<P> Function(MessageHandlerContext<M, D, C>) payload, {
    MessageActionDescriptor<M, D, C>? action,
    bool reenterTarget = false,
  }) {
    goTo(channel.to, payload: payload, reenterTarget: reenterTarget, action: action);
  }
}

/// Provides methods for describing how a state, carrying state data of type [D], behaves in
/// response to a message of type [M].
///
/// In some specialized situations, the builder may also carry a contextual value type [C]. In the
/// general case [C] will be `void`.
///
/// A [MessageHandlerBuilder] is provided to the build callback provided to [StateBuilder.onMessage],
/// and is used to describe how messages of a particular type are handled by a state.
///
/// ```dart
/// class MyMessage {}
/// var state1 = StateKey('s1');
/// var state2 = StateKey('s2');
/// var builder = StateTreeBuilder(initialState: state1);
/// builder.state(state1, (b) {
///   // Describe how state responds to MyMessage messages
///   b.onMessage<MyMessage>((b) => b.goTo(state2));
/// });
/// ```
class MessageHandlerBuilder<M, D, C> extends _MessageHandlerBuilder<M, D, C>
    with _GoToHandlerBuilderMixin<M, D, C> {
  MessageHandlerBuilder(
    StateKey forState,
    FutureOr<C> Function(MessageContext) makeContext,
    Logger log,
    String? messageName,
  ) : super(forState, makeContext, log, messageName);

  /// Indicates that the message has been handled, and that a self transition should occur.
  ///
  /// During a self-transition this state will be exited and re-entered.
  ///
  /// If [action] is provided, this action will be invoked before the transition occurs. The [act]
  /// builder can be used to specify this action.
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  void goToSelf({
    TransitionHandler? transitionAction,
    MessageActionDescriptor<M, D, C>? action,
    String? label,
  }) {
    descriptor = makeGoToSelfDescriptor<M, D, C>(
      _makeContext,
      _log,
      transitionAction,
      action,
      label,
      _messageName,
    );
  }

  /// Indicates that the message has been handled, and no state transition should occur.
  ///
  /// If [action] is provided, this action will be invoked as the message is being handled. The
  /// [act] builder can be used to specify this action.
  void stay({MessageActionDescriptor<M, D, C>? action}) {
    descriptor = makeStayOrUnhandledDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      action,
      action?.info.label,
      _messageName,
      handled: true,
    );
  }

  /// Indicates that an action should take place when handling a message, and
  /// that no state transition should occur.
  ///
  /// The [act] builder can be used to specify the action that should take place.
  void action(
    MessageActionDescriptor<M, D, C> action, [
    ActionResult actionResult = ActionResult.handled,
  ]) {
    descriptor = makeStayOrUnhandledDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      action,
      null,
      _messageName,
      handled: actionResult == ActionResult.handled,
    );
  }

  /// Indicates that the message has not been handled, and the message should be dispatched to
  /// ancestor states for processing.
  ///
  /// If [action] is provided, this action will be invoked before any ancestor states handle the
  /// message. The [act] builder can be used to specify this action.
  void unhandled({MessageActionDescriptor<M, D, C>? action}) {
    descriptor = makeStayOrUnhandledDescriptor<M, D, C>(
      _makeContext,
      _log,
      _forState,
      action,
      action?.info.label,
      _messageName,
      handled: false,
    );
  }

  /// Describes message handling behavior that may be run conditionally, sharing a context value
  /// among conditions.
  ///
  /// The returned [MessageHandlerWhenBuilder] may be used to define additional conditional
  /// behavior, including a fallback [MessageHandlerWhenBuilder.otherwise] condition.
  ///
  /// When the message is being processed, the [condition] functions are evaluated. If the function
  /// returns `true`, the behavior described by the [buildTrue] callback will take place. If more
  /// than one condition is defined, the conditions are evaluated in the order they are
  /// defined by calls to [MessageHandlerWhenBuilder.when].
  MessageHandlerWhenBuilder<M, D, C> when(
    FutureOr<bool> Function(MessageHandlerContext<M, D, C>) condition,
    void Function(MessageHandlerBuilder<M, D, C> builder) buildTrue, {
    String? label,
  }) {
    var conditions = <MessageConditionDescriptor<M, D, C>>[];
    var whenBuilder = MessageHandlerWhenBuilder<M, D, C>(
      () => MessageHandlerBuilder<M, D, C>(_forState, _makeContext, _log, _messageName),
      conditions,
    );

    whenBuilder.when(condition, buildTrue, label: label);
    descriptor =
        makeWhenMessageDescriptor<M, D, C>(conditions, _makeContext, _log, label, _messageName);
    return whenBuilder;
  }

  /// Describes message handling behavior that may be run conditionally, sharing a context value
  /// among conditions.
  ///
  /// This method is similar to [when], but a [context] function providing a contextual value is
  /// first called before evaluating any conditions. The context value can be accessed by the
  /// conditions with the [MessageHandlerContext.context] property. This may be useful in
  /// avoiding generating the context value repeatedly in each condition.
  ///
  /// The returned [MessageHandlerWhenBuilder] may be used to define additional conditional
  /// behavior, including a fallback [MessageHandlerWhenBuilder.otherwise] condition.
  ///
  /// When the message is being processed, the [condition] functions are evaluated. If the function
  /// returns `true`, the behavior described by the [buildTrue] callback will take place. If more
  /// than one condition is defined, the conditions are evaluated in the order they are
  /// defined by calls to [MessageHandlerWhenBuilder.when].
  MessageHandlerWhenBuilder<M, D, C2> whenWith<C2>(
    FutureOr<C2> Function(MessageHandlerContext<M, D, C> ctx) context,
    FutureOr<bool> Function(MessageHandlerContext<M, D, C2> ctx) condition,
    void Function(MessageHandlerBuilder<M, D, C2> builder) buildTrue, {
    String? label,
  }) {
    var contextRef = Ref<C2?>(null);
    var conditions = <MessageConditionDescriptor<M, D, C2>>[];
    var whenBuilder = MessageHandlerWhenBuilder<M, D, C2>(
      () => MessageHandlerBuilder<M, D, C2>(
        _forState,
        (_) => contextRef.value!,
        _log,
        _messageName,
      ),
      conditions,
    );

    whenBuilder.when(condition, buildTrue, label: label);
    descriptor = makeWhenWithContextMessageDescriptor<M, D, C, C2>(
      context,
      conditions,
      _makeContext,
      _log,
      label,
      _messageName,
    );
    return whenBuilder;
  }

  /// Describes message handling behavior that runs conditionally, depending on a [Result] value.
  ///
  /// When the message is processed, the [result] function is evaluated, and the returned [Result] is
  /// used to determine the handler behavior. If [Result.isValue] is `true`, then the behavior
  /// described by the [buildSuccess] callback will take place. If [Result.isError] is true, then
  /// an exception will be raised. However, [MessageHandlerWhenResultBuilder.otherwise] can be
  /// used to override the default error handling.
  MessageHandlerWhenResultBuilder<M, D, C, T> whenResult<T>(
    FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
    void Function(MessageHandlerBuilder<M, D, T> builder) buildSuccess, {
    String? label,
  }) {
    var whenResultBuilder = MessageHandlerWhenResultBuilder<M, D, C, T>._(
      this,
      result,
      buildSuccess,
      label,
    );

    descriptor = whenResultBuilder.descriptor;

    return whenResultBuilder;
  }
}

/// Provides methods for describing how a [StateTreeBuilder.machineState] behaves when its nested
/// state machine completes.
///
/// Because nothing meaningful can be done with the completed state machine , the
/// [StateTreeBuilder.machineState] must transition to a new state on completion.  Therefore the
/// methods of this builder can only be used to specifiy a transition.
class MachineDoneHandlerBuilder<C> extends _MessageHandlerBuilder<Object, NestedMachineData, C>
    with _GoToHandlerBuilderMixin<Object, NestedMachineData, C> {
  MachineDoneHandlerBuilder._(
    StateKey forState,
    FutureOr<C> Function(MessageContext) makeContext,
    Logger log,
    String? messageName,
  ) : super(forState, makeContext, log, messageName);

  /// Adds a conditional behavior, in the same manner as [MessageHandlerBuilder.when].
  MachineDoneWhenBuilder<C> when(
    FutureOr<bool> Function(MessageHandlerContext<Object, NestedMachineData, C>) condition,
    void Function(MachineDoneHandlerBuilder<C> builder) buildTrueHandler, {
    String? label,
  }) {
    var conditions = <MessageConditionDescriptor<Object, NestedMachineData, C>>[];
    var whenBuilder = MachineDoneWhenBuilder<C>(
      () => MachineDoneHandlerBuilder<C>._(_forState, _makeContext, _log, _messageName),
      conditions,
    );

    whenBuilder.when(condition, buildTrueHandler, label: label);
    descriptor = makeWhenMessageDescriptor<Object, NestedMachineData, C>(
      conditions,
      _makeContext,
      _log,
      label,
      _messageName,
    );
    return whenBuilder;
  }

  MachineDoneWhenResultBuilder<C, T> whenResult<T>(
    FutureOr<Result<T>> Function(MessageHandlerContext<Object, NestedMachineData, C>) result,
    void Function(MachineDoneHandlerBuilder<T> builder) buildSuccessHandler, {
    String? label,
  }) {
    var whenResultBuilder = MachineDoneWhenResultBuilder<C, T>._(
      this,
      result,
      buildSuccessHandler,
      label,
    );

    descriptor = whenResultBuilder.descriptor;

    return whenResultBuilder;
  }
}

class _MessageHandlerWhenBuilder<M, D, C, B extends _MessageHandlerDescriptorProvider<C>> {
  final B Function() _makeBuilder;
  final List<MessageConditionDescriptor<M, D, C>> _conditions;

  _MessageHandlerWhenBuilder(
    this._makeBuilder,
    this._conditions,
  );

  void _when(
    FutureOr<bool> Function(MessageHandlerContext<M, D, C>) condition,
    void Function(B builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = _makeBuilder();
    buildTrueHandler(trueBuilder);
    var descriptor = trueBuilder.descriptor;

    if (descriptor != null) {
      _conditions.add(MessageConditionDescriptor<M, D, C>(
        MessageConditionInfo(label, descriptor.info),
        condition,
        descriptor,
      ));
    }
  }

  void otherwise(
    void Function(B builder) buildOtherwise, {
    String? label,
  }) {
    var builder = _makeBuilder();
    buildOtherwise(builder);
    var descriptor = builder.descriptor;

    if (descriptor != null) {
      _conditions.add(MessageConditionDescriptor<M, D, C>(
        MessageConditionInfo(label, descriptor.info),
        (ctx) => true,
        descriptor,
      ));
    }
  }
}

/// Provides methods for defining conditional message handling behavior for messages of type [M],
/// for a state carrying state data type [D], and a context value of type [C].
class MessageHandlerWhenBuilder<M, D, C>
    extends _MessageHandlerWhenBuilder<M, D, C, MessageHandlerBuilder<M, D, C>> {
  MessageHandlerWhenBuilder(
    MessageHandlerBuilder<M, D, C> Function() makeBuilder,
    List<MessageConditionDescriptor<M, D, C>> conditions,
  ) : super(makeBuilder, conditions);

  /// Describes message handling behavior that may be run conditionally.
  ///
  /// The returned [MessageHandlerWhenBuilder] may be used to define additional conditional
  /// behavior, including a fallback [MessageHandlerWhenBuilder.otherwise] condition.
  ///
  /// When the message is being processed, the [condition] functions are evaluated. If the function
  /// returns `true`, the behavior described by the [buildTrue] callback will take place. If more
  /// than one condition is defined, the conditions are evaluated in the order they are
  /// defined by calls to [MessageHandlerWhenBuilder.when].
  MessageHandlerWhenBuilder<M, D, C> when(
    FutureOr<bool> Function(MessageHandlerContext<M, D, C>) condition,
    void Function(MessageHandlerBuilder<M, D, C> builder) buildTrue, {
    String? label,
  }) {
    _when(condition, buildTrue, label: label);
    return this;
  }
}

/// Provides methods for defining conditional behavior of a [StateTreeBuilder.machineState], when the
/// nested state machine completes.
class MachineDoneWhenBuilder<C>
    extends _MessageHandlerWhenBuilder<Object, NestedMachineData, C, MachineDoneHandlerBuilder<C>> {
  MachineDoneWhenBuilder(
    MachineDoneHandlerBuilder<C> Function() makeBuilder,
    List<MessageConditionDescriptor<Object, NestedMachineData, C>> conditions,
  ) : super(makeBuilder, conditions);

  MachineDoneWhenBuilder<C> when(
    FutureOr<bool> Function(MessageHandlerContext<Object, NestedMachineData, C>) condition,
    void Function(MachineDoneHandlerBuilder<C> builder) buildTrue, {
    String? label,
  }) {
    _when(condition, buildTrue, label: label);
    return this;
  }
}

// Well that escalated quickly....
class _MessageHandlerWhenResultBuilder<
    M,
    D,
    C,
    T,
    BSuccess extends _MessageHandlerDescriptorProvider<T>,
    BError extends _MessageHandlerDescriptorProvider<AsyncError>> {
  final _resultRef = Ref<Result<T>?>(null);
  final _failureDescrRef = Ref<MessageHandlerDescriptor<AsyncError>?>(null);
  final BError Function(Ref<Result<T>?> resultRef) _makeErrorBuilder;
  MessageHandlerDescriptor<C>? descriptor;

  _MessageHandlerWhenResultBuilder(
    _MessageHandlerBuilder<M, D, C> parentBuilder,
    BSuccess Function(Ref<Result<T>?> resultRef) makeSuccessBuilder,
    this._makeErrorBuilder,
    FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
    void Function(BSuccess builder) buildSuccessHandler,
    String? label,
  ) {
    var successBuilder = makeSuccessBuilder(_resultRef);
    buildSuccessHandler(successBuilder);
    var successDesr = successBuilder.descriptor;

    if (successDesr != null) {
      descriptor = makeWhenResultMessageDescriptor<M, D, C, T>(
        parentBuilder._forState,
        result,
        parentBuilder._makeContext,
        _resultRef,
        successDesr,
        _failureDescrRef,
        parentBuilder._log,
        label,
        parentBuilder._messageName,
      );
    }
  }

  /// Adds a message handling behavior that will take place when [Result.isError] is `true`.
  ///
  /// The [buildError] callback is used to define the behavior that should take place.
  void otherwise(
    void Function(BError builder) buildError, {
    String? label,
  }) {
    var errorBuilder = _makeErrorBuilder(_resultRef);
    buildError(errorBuilder);
    _failureDescrRef.value = errorBuilder.descriptor;
  }
}

/// Provides methods for error handling behavior for a state carrying state data
/// of type [D] and a context value of type [C], when a [Result] is an error value.
class MessageHandlerWhenResultBuilder<M, D, C, T> extends _MessageHandlerWhenResultBuilder<M, D, C,
    T, MessageHandlerBuilder<M, D, T>, MessageHandlerBuilder<M, D, AsyncError>> {
  MessageHandlerWhenResultBuilder._(
    MessageHandlerBuilder<M, D, C> parentBuilder,
    FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
    void Function(MessageHandlerBuilder<M, D, T> builder) buildSuccessHandler,
    String? label,
  ) : super(
            parentBuilder,
            (resultRef) => MessageHandlerBuilder<M, D, T>(
                parentBuilder._forState,
                (_) => resultRef.value!.asValue!.value,
                parentBuilder._log,
                parentBuilder._messageName),
            (resultRef) => MessageHandlerBuilder<M, D, AsyncError>(parentBuilder._forState, (_) {
                  var err = resultRef.value!.asError!;
                  return AsyncError(err.error, err.stackTrace);
                }, parentBuilder._log, parentBuilder._messageName),
            result,
            buildSuccessHandler,
            label);
}

/// Provides methods for error handling behavior for a [StateTreeBuilder.machineState] carrying
/// context value of type [C], when a nested state machine has completted, and when a [Result] is
/// an error value.
class MachineDoneWhenResultBuilder<C, T> extends _MessageHandlerWhenResultBuilder<Object,
    NestedMachineData, C, T, MachineDoneHandlerBuilder<T>, MachineDoneHandlerBuilder<AsyncError>> {
  MachineDoneWhenResultBuilder._(
    MachineDoneHandlerBuilder<C> parentBuilder,
    FutureOr<Result<T>> Function(MessageHandlerContext<Object, NestedMachineData, C>) result,
    void Function(MachineDoneHandlerBuilder<T> builder) buildSuccessHandler,
    String? label,
  ) : super(
            parentBuilder,
            (resultRef) => MachineDoneHandlerBuilder<T>._(
                parentBuilder._forState,
                (_) => resultRef.value!.asValue!.value,
                parentBuilder._log,
                parentBuilder._messageName),
            (resultRef) => MachineDoneHandlerBuilder<AsyncError>._(parentBuilder._forState, (_) {
                  var err = resultRef.value!.asError!;
                  return AsyncError(err.error, err.stackTrace);
                }, parentBuilder._log, parentBuilder._messageName),
            result,
            buildSuccessHandler,
            label);
}
