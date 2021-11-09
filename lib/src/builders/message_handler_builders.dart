part of tree_builders;

/// Describes the message processing result of runnin an action with [MessageHandlerBuilder.action].
enum ActionResult {
  /// The message was handled, and the state machine should stay in the current state.
  handled,

  /// The message was unhandled, and should be dispatched to a parent state for processing.
  unhandled,
}

/// Provides methods for describing how a state behaves in response to a message of type [M].
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
class MessageHandlerBuilder<M> {
  final StateKey _forState;
  final String? _messageName;
  _MessageHandlerDescriptor? _handler;

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
  ///     action: b.act.run((msgCtx, msg) =>
  ///       print('Going to $state2 in response to message $msg')));
  /// });
  late final MessageActionBuilder<M> act = MessageActionBuilder<M>._(_forState);

  MessageHandlerBuilder._(this._forState, this._messageName);

  /// Indicates that a transition to [targetState] should occur.
  ///
  /// If [action] is provided, this action will be invoked before the transition occurs. The [act]
  /// builder can be used to specify this action.
  ///
  /// If [payload] is provided, this function will be called to generate a value for
  /// [TransitionContext.payload] before the transition occurs.
  ///
  /// If [transitionAction] is specified, this function will be called during the transition
  /// between states, after all states are exited, but before entering any new states.
  ///
  /// If [reenterTarget] is true, then the target state will be re-enterd (that is, its exit and
  /// entry handlers will be called), even if the state is already active.
  ///
  /// The state transition can be labeled when formatting a state tree by providing a [label].
  void goTo(
    StateKey targetState, {
    TransitionHandler? transitionAction,
    bool reenterTarget = false,
    FutureOr<Object?> Function(MessageContext ctx, M message)? payload,
    _MessageAction<M>? action,
    String? label,
  }) {
    _handler = _GoToDescriptor.createForMessage<M>(
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
    _MessageAction<M>? action,
    String? label,
  }) {
    _handler = _GoToSelfDescriptor.createForMessage<M>(
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
  void stay({_MessageAction<M>? action}) {
    _handler = _StayOrUnhandledDescriptor.createForMessage<M>(
      _forState,
      action,
      action?.label,
      _messageName,
      handled: true,
    );
  }

  /// Indicates that the message has not been handled, and the message should be dispatched to
  /// ancestor states for processing.
  ///
  /// If [action] is provided, this action will be invoked before any ancestor states handle the
  /// message. The [act] builder can be used to specify this action.
  void unhandled({_MessageAction<M>? action}) {
    _handler = _StayOrUnhandledDescriptor.createForMessage<M>(
      _forState,
      action,
      action?.label,
      _messageName,
      handled: false,
    );
  }

  void action(
    _MessageAction<M> action, [
    ActionResult actionResult = ActionResult.handled,
  ]) {
    _handler = _StayOrUnhandledDescriptor.createForMessage<M>(
      _forState,
      action,
      action.label,
      _messageName,
      handled: actionResult == ActionResult.handled,
    );
  }

  void enterChannel<P>(
    Channel<P> channel,
    FutureOr<P> Function(MessageContext msgCtx, M msg) payload, {
    bool reenterTarget = false,
  }) {
    var channelEntry = channel._entry(payload);
    channelEntry.enter(this, reenterTarget);
  }

  MessageHandlerWhenBuilder<M> when(
    FutureOr<bool> Function(MessageContext msgCtx, M msg) condition,
    void Function(MessageHandlerBuilder<M>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = MessageHandlerBuilder<M>._(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    var conditions = [_MessageCondition(condition, trueBuilder._handler!, label)];
    _handler = _WhenDescriptor.createForMessage<M>(conditions);
    return MessageHandlerWhenBuilder<M>(_forState, conditions, _messageName);
  }

  MessageHandlerWhenWithContextBuilder<M, T> whenWith<T>(
    FutureOr<T> Function(MessageContext ctx, M message) context,
    FutureOr<bool> Function(MessageContext msgCtx, M msg, T ctx) condition,
    void Function(MessageHandlerBuilder<M>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = MessageHandlerBuilder<M>._(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    var conditions = [
      _MessageConditionWithContext<M, T>(
        condition,
        trueBuilder._handler!,
        label,
      )
    ];
    _handler = _WhenWithContextDescriptor.createForMessage<M, T>(context, conditions);
    return MessageHandlerWhenWithContextBuilder<M, T>(_forState, conditions, _messageName);
  }

  MessageHandlerWhenResultBuilder<M, T> whenResult<T>(
    FutureOr<Result<T>> Function(MessageContext msgCtx, M msg) result,
    void Function(ContinuationMessageHandlerBuilder<M, T>) buildTrueHandler, {
    String? label,
  }) {
    var continuationBuilder = ContinuationMessageHandlerBuilder<M, T>(_forState);
    buildTrueHandler(continuationBuilder);

    var refFailure = Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?>(null);
    _handler = _WhenResultDescriptor.createForMessage<M, T>(
      _forState,
      result,
      continuationBuilder._continuationHandler!,
      refFailure,
      label,
      null,
    );
    return MessageHandlerWhenResultBuilder<M, T>(_forState, refFailure);
  }
}

class DataMessageHandlerBuilder<M, D> {
  final StateKey _forState;
  final String? _messageName;
  late final act = MessageActionWithDataBuilder<M, D>._(_forState);
  _MessageHandlerDescriptor? _handler;

  DataMessageHandlerBuilder(this._forState, this._messageName);

  void goTo(
    StateKey targetState, {
    TransitionHandler? transitionAction,
    bool reenterTarget = false,
    FutureOr<Object?> Function(MessageContext ctx, M message, D data)? payload,
    _MessageActionWithData<M, D>? action,
    String? label,
  }) {
    _handler = _GoToDescriptor.createForMessageAndData<M, D>(
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

  void goToSelf({
    TransitionHandler? transitionAction,
    _MessageActionWithData<M, D>? action,
    String? label,
  }) {
    _handler = _GoToSelfDescriptor.createForMessagAndData<M, D>(
      transitionAction,
      action,
      label,
      _messageName,
    );
  }

  void stay({
    _MessageActionWithData<M, D>? action,
    String? label,
  }) {
    _handler = _StayOrUnhandledDescriptor.createForMessageAndData<M, D>(
      _forState,
      action,
      label,
      _messageName,
      handled: true,
    );
  }

  void unhandled({_MessageActionWithData<M, D>? action}) {
    _handler = _StayOrUnhandledDescriptor.createForMessageAndData<M, D>(
      _forState,
      action,
      action?.label,
      _messageName,
      handled: true,
    );
  }

  void action(
    _MessageActionWithData<M, D> Function(MessageActionWithDataBuilder<M, D>) buildAction, [
    ActionResult actionResult = ActionResult.handled,
  ]) {
    var action = buildAction(act);
    _handler = _StayOrUnhandledDescriptor.createForMessageAndData<M, D>(
      _forState,
      action,
      action.label,
      _messageName,
      handled: actionResult == ActionResult.handled,
    );
  }

  void enterChannel<P>(
    Channel<P> channel,
    FutureOr<P> Function(MessageContext msgCtx, M msg, D data) payload, {
    bool reenterTarget = false,
  }) {
    var channelEntry = channel._entryWithData(payload);
    channelEntry.enter(this, reenterTarget);
  }

  MessageHandlerWhenWithDataBuilder<M, D> when(
    FutureOr<bool> Function(MessageContext msgCtx, M msg, D data) condition,
    void Function(DataMessageHandlerBuilder<M, D>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = DataMessageHandlerBuilder<M, D>(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    var conditions = [_MessageConditionWithContext(condition, trueBuilder._handler!, label)];
    _handler = _WhenDescriptor.createForMessageAndData<M, D>(conditions);
    return MessageHandlerWhenWithDataBuilder<M, D>(_forState, conditions, _messageName);
  }

  MessageHandlerWhenWithDataAndContextBuilder<M, D, T> whenWith<T>(
    FutureOr<T> Function(MessageContext ctx, M message, D data) context,
    FutureOr<bool> Function(MessageContext msgCtx, M msg, D data, T ctx) condition,
    void Function(DataMessageHandlerBuilder<M, D>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = DataMessageHandlerBuilder<M, D>(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    var conditions = [
      _MessageConditionWithDataAndContext<M, D, T>(
        condition,
        trueBuilder._handler!,
        label,
      )
    ];
    _handler = _WhenWithContextDescriptor.createForMessageAndData<M, D, T>(context, conditions);
    return MessageHandlerWhenWithDataAndContextBuilder<M, D, T>(
        _forState, conditions, _messageName);
  }

  MessageHandlerWhenResultWithDataBuilder<M, D, T> whenResult<T>(
    FutureOr<Result<T>> Function(MessageContext msgCtx, M msg, D data) result,
    void Function(ContinuationWithDataMessageHandlerBuilder<M, D, T>) buildTrueHandler, {
    String? label,
  }) {
    var continuationBuilder = ContinuationWithDataMessageHandlerBuilder<M, D, T>(_forState);
    buildTrueHandler(continuationBuilder);

    var refFailure = Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?>(null);
    _handler = _WhenResultDescriptor.createForMessageAndData<M, D, T>(
      _forState,
      result,
      continuationBuilder._continuationHandler!,
      refFailure,
      label,
      null,
    );
    return MessageHandlerWhenResultWithDataBuilder<M, D, T>(_forState, refFailure);
  }
}

class ContinuationMessageHandlerBuilder<M, T> {
  final StateKey _forState;
  _ContinuationMessageHandlerDescriptor<T>? _continuationHandler;
  final ContinuationMessageActionBuilder<M, T> act = ContinuationMessageActionBuilder<M, T>();

  ContinuationMessageHandlerBuilder(this._forState);

  void goTo(StateKey targetState,
      {TransitionHandler? transitionAction,
      bool reenterTarget = false,
      FutureOr<Object?> Function(MessageContext msgCtx, M msg, T ctx)? payload,
      _ContinuationMessageAction<M, T>? action,
      String? label}) {
    _continuationHandler = _ContinuationGoToDescriptor.createForMessage<M, T>(
      _forState,
      targetState,
      transitionAction,
      reenterTarget,
      payload,
      action,
      null,
      label,
    );
  }

  void goToSelf({
    TransitionHandler? transitionAction,
    _ContinuationMessageAction<M, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationGoToSelfDescriptor.createForMessage<M, T>(
      transitionAction,
      action,
      null,
      label,
    );
  }

  void stay({
    _ContinuationMessageAction<M, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationStayOrUnhandledDescriptor.createForMessage<M, T>(
      _forState,
      action,
      label,
      null,
      handled: true,
    );
  }

  void unhandled({
    _ContinuationMessageAction<M, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationStayOrUnhandledDescriptor.createForMessage<M, T>(
      _forState,
      action,
      label,
      null,
      handled: false,
    );
  }

  void action(
    _ContinuationMessageAction<M, T> Function(ContinuationMessageActionBuilder<M, T>) buildAction, [
    ActionResult actionResult = ActionResult.handled,
  ]) {
    var action = buildAction(act);
    _continuationHandler = _ContinuationStayOrUnhandledDescriptor.createForMessage<M, T>(
      _forState,
      action,
      action.label,
      null,
      handled: actionResult == ActionResult.handled,
    );
  }

  void enterChannel<P>(
    Channel<P> channel,
    FutureOr<P> Function(MessageContext msgCtx, M msg, T ctx) payload, {
    bool reenterTarget = false,
  }) {
    var channelEntry = channel._entryWithResult(payload);
    channelEntry.enter(this, reenterTarget);
  }
}

class ContinuationWithDataMessageHandlerBuilder<M, D, T> {
  final StateKey _forState;
  _ContinuationMessageHandlerDescriptor<T>? _continuationHandler;
  final ContinuationMessageActionWithDataBuilder<M, D, T> act =
      ContinuationMessageActionWithDataBuilder<M, D, T>();

  ContinuationWithDataMessageHandlerBuilder(this._forState);

  void goTo(
    StateKey targetState, {
    TransitionHandler? transitionAction,
    bool reenterTarget = false,
    FutureOr<Object?> Function(MessageContext msgCtx, M msg, D data, T ctx)? payload,
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationGoToDescriptor.createForMessageAndData<M, D, T>(
      _forState,
      targetState,
      transitionAction,
      reenterTarget,
      payload,
      action,
      null,
      label,
    );
  }

  void goToSelf({
    TransitionHandler? transitionAction,
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationGoToSelfDescriptor.createForMessageAndData<M, D, T>(
      transitionAction,
      action,
      null,
      label,
    );
  }

  void stay({
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationStayOrUnhandledDescriptor.createForMessageAndData<M, D, T>(
      _forState,
      action,
      null,
      label,
      handled: true,
    );
  }

  void unhandled({
    _ContinuationMessageActionWithData<M, D, T>? action,
    String? label,
  }) {
    _continuationHandler = _ContinuationStayOrUnhandledDescriptor.createForMessageAndData<M, D, T>(
      _forState,
      action,
      label,
      null,
      handled: false,
    );
  }

  void action(
    _ContinuationMessageActionWithData<M, D, T> action, [
    ActionResult actionResult = ActionResult.handled,
  ]) {
    _continuationHandler = _ContinuationStayOrUnhandledDescriptor.createForMessageAndData<M, D, T>(
      _forState,
      action,
      action.label,
      null,
      handled: actionResult == ActionResult.handled,
    );
  }

  void enterChannel<P>(
    Channel<P> channel,
    FutureOr<P> Function(MessageContext msgCtx, M msg, D data, T ctx) payload, {
    bool reenterTarget = false,
  }) {
    var channelEntry = channel._entryWithDataAndResult<M, D, T>(payload);
    channelEntry.enter(this, reenterTarget);
  }
}

class MessageHandlerWhenBuilder<M> {
  final StateKey _forState;
  final String? _messageName;
  final List<_MessageCondition<M>> _conditions;
  MessageHandlerWhenBuilder(this._forState, this._conditions, this._messageName);

  MessageHandlerWhenBuilder<M> when(
    FutureOr<bool> Function(MessageContext msgCtx, M msg) condition,
    void Function(MessageHandlerBuilder<M>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = MessageHandlerBuilder<M>._(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    _conditions.add(_MessageCondition(condition, trueBuilder._handler!, label));
    return this;
  }

  void otherwise(
    void Function(MessageHandlerBuilder<M>) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = MessageHandlerBuilder<M>._(_forState, _messageName);
    buildOtherwise(otherwiseBuilder);
    _conditions.add(_MessageCondition((msgCts, msg) => true, otherwiseBuilder._handler!, label));
  }
}

class MessageHandlerWhenWithContextBuilder<M, T> {
  final StateKey _forState;
  final String? _messageName;
  final List<_MessageConditionWithContext<M, T>> _conditions;
  MessageHandlerWhenWithContextBuilder(this._forState, this._conditions, this._messageName);

  MessageHandlerWhenWithContextBuilder<M, T> when(
    FutureOr<bool> Function(MessageContext msgCtx, M msg, T ctx) condition,
    void Function(MessageHandlerBuilder<M>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = MessageHandlerBuilder<M>._(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    _conditions.add(_MessageConditionWithContext(
      condition,
      trueBuilder._handler!,
      label,
    ));
    return this;
  }

  void otherwise(
    void Function(MessageHandlerBuilder<M>) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = MessageHandlerBuilder<M>._(_forState, _messageName);
    buildOtherwise(otherwiseBuilder);
    _conditions.add(_MessageConditionWithContext(
      (msgCtx, msg, ctx) => true,
      otherwiseBuilder._handler!,
      label,
    ));
  }
}

class MessageHandlerWhenWithDataAndContextBuilder<M, D, T> {
  final StateKey _forState;
  final String? _messageName;
  final List<_MessageConditionWithDataAndContext<M, D, T>> _conditions;
  MessageHandlerWhenWithDataAndContextBuilder(this._forState, this._conditions, this._messageName);

  MessageHandlerWhenWithDataAndContextBuilder<M, D, T> when(
    FutureOr<bool> Function(MessageContext msgCtx, M msg, D data, T ctx) condition,
    void Function(DataMessageHandlerBuilder<M, D>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = DataMessageHandlerBuilder<M, D>(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    _conditions.add(_MessageConditionWithDataAndContext(
      condition,
      trueBuilder._handler!,
      label,
    ));
    return this;
  }

  void otherwise(
    void Function(DataMessageHandlerBuilder<M, D>) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = DataMessageHandlerBuilder<M, D>(_forState, _messageName);
    buildOtherwise(otherwiseBuilder);
    _conditions.add(_MessageConditionWithDataAndContext(
      (msgCtx, msg, ctx, data) => true,
      otherwiseBuilder._handler!,
      label,
    ));
  }
}

class MessageHandlerWhenWithDataBuilder<M, D> {
  final StateKey _forState;
  final String? _messageName;
  final List<_MessageConditionWithContext<M, D>> _conditions;
  MessageHandlerWhenWithDataBuilder(this._forState, this._conditions, this._messageName);

  MessageHandlerWhenWithDataBuilder<M, D> when(
    FutureOr<bool> Function(MessageContext msgCtx, M msg, D data) condition,
    void Function(DataMessageHandlerBuilder<M, D>) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = DataMessageHandlerBuilder<M, D>(_forState, _messageName);
    buildTrueHandler(trueBuilder);
    _conditions.add(_MessageConditionWithContext(
      condition,
      trueBuilder._handler!,
      label,
    ));
    return this;
  }

  void otherwise(
    void Function(DataMessageHandlerBuilder<M, D>) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = DataMessageHandlerBuilder<M, D>(_forState, _messageName);
    buildOtherwise(otherwiseBuilder);
    _conditions.add(_MessageConditionWithContext(
      (msgCtx, msg, ctx) => true,
      otherwiseBuilder._handler!,
      label,
    ));
  }
}

class MessageHandlerWhenResultBuilder<M, T> {
  final StateKey _forState;
  final Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?> _failureContinuationRef;

  MessageHandlerWhenResultBuilder(this._forState, this._failureContinuationRef);

  void otherwise(
    void Function(ContinuationMessageHandlerBuilder<M, AsyncError>) buildErrorHandler, {
    String? label,
  }) {
    var errorBuilder = ContinuationMessageHandlerBuilder<M, AsyncError>(_forState);
    buildErrorHandler(errorBuilder);
    _failureContinuationRef.value = errorBuilder._continuationHandler;
  }
}

class MessageHandlerWhenResultWithDataBuilder<M, D, T> {
  final StateKey _forState;
  final Ref<_ContinuationMessageHandlerDescriptor<AsyncError>?> _failureContinuationRef;

  MessageHandlerWhenResultWithDataBuilder(this._forState, this._failureContinuationRef);

  void otherwise(
    void Function(ContinuationWithDataMessageHandlerBuilder<M, D, AsyncError>) buildErrorHandler, {
    String? label,
  }) {
    var errorBuilder = ContinuationWithDataMessageHandlerBuilder<M, D, AsyncError>(_forState);
    buildErrorHandler(errorBuilder);
    _failureContinuationRef.value = errorBuilder._continuationHandler;
  }
}
