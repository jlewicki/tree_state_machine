part of tree_builders;

enum _ActionType {
  schedule,
  post,
  updateData,
  run,
}

abstract class _MessageActionInfo {
  _ActionType get actionType;
  String? get label;
  Type? get postMessageType;
}

class _MessageAction<M> implements _MessageActionInfo {
  final FutureOr<void> Function(MessageContext msgCtx, M msg) _action;
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;

  _MessageAction._(this.actionType, this._action, this.postMessageType, this.label);

  static FutureOr<void> _empty<M>(MessageContext msgCtx, M msg) {}
}

/// Provides methods for describing actions that can be taken while a state handles a message.
///
/// A [MessageActionBuilder] is accessed from the [MessageHandlerBuilder.act] property.
/// ```dart
/// void onMessage<M>(MessageContext ctx, M message) => print('Handling message');
///
/// var state1 = StateKey('s1');
/// var state2 = StateKey('s2');
/// var builder = StateTreeBuilder(initialState: state1);
///
/// builder.state(state1, (b) {
///   // Calls the onMessage function as a side effect before the transition occurs
///   b.onMessage<MyMessage>((b) => b.goTo(state2, action: b.act.run(onMessage)));
/// });
/// ```
class MessageActionBuilder<M> {
  final StateKey _forState;
  final _logger = Logger('tree_state_machine.MessageActionBuilder<$M>');
  MessageActionBuilder._(this._forState);

  /// Runs the [action] while a message is being handled.
  ///
  /// When the action function is called, it is passed a [MessageContext], and the message that is
  /// being handled.
  /// ```dart
  /// void onMessage<M>(MessageContext ctx, M message) => print('Handling message');
  ///
  /// var state1 = StateKey('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Calls the onMessage function as a side effect before the transition occurs
  ///   b.onMessage<MyMessage>((b) => b.goTo(state2, action: b.act.run(onMessage);
  /// });
  /// ```
  /// This action can be labeled when formatting a state tree by providing a [label].
  _MessageAction<M> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg) action, {
    String? label,
  }) {
    return _MessageAction<M>._(_ActionType.run, (msgCtx, msg) {
      _logger.fine(() => "State '$_forState' is running a message action.");
      action(msgCtx, msg);
    }, null, label);
  }

  /// Updates state data of type [D] while a message is being handled.
  ///
  /// When [update] function is called, it is provided a [MessageContext], the message that is
  /// being handled, and the current state data value.
  /// ```dart
  /// enum Messages { increment  }
  /// var countingState = StateKey('counting');
  /// var builder = new StateTreeBuilder(initialState: countingState);
  ///
  /// builder.dataState<int>(
  ///   countingState,
  ///   InitialData.value(1),
  ///   (b) {
  ///     b.onMessageValue<Messages>(Messages.increment, (b) {
  ///       // Updates state data as a side effect while the message is handled.
  ///       b.stay(action: b.act.updateData((ctx, msg, counter) => counter + 1));
  ///     });
  ///   });
  /// ```
  /// This action can be labeled when formatting a state tree by providing a [label].
  _MessageAction<M> updateData<D>(
    D Function(MessageContext msgCtx, M msg, D current) update, {
    StateKey? forState,
    String? label,
  }) {
    return _MessageAction<M>._(
      _ActionType.updateData,
      (msgCtx, msg) {
        _logger.fine(() => "State '$_forState' is updating data of type $D");
        msgCtx.dataOrThrow<D>(forState).update((d) => update(msgCtx, msg, d));
      },
      null,
      label,
    );
  }

  /// Schedules a message to be processed by the state machine while a message is being handled.
  ///
  /// If [getMessage] is provided, the function will be evaluated to produce a message function
  /// which will be called on each scheduling interval to produce the message to post. When
  /// [getMessage] is called, it is provided a [MessageContext] and the message that is being
  /// handled. If [getMessage] is not provided, then [message] must be.
  ///
  /// The scheduling will be performed using [TransitionContext.schedule]. Refer to that method
  /// for further details of scheduling semantics.
  ///
  /// ```dart
  /// class DoItLater {}
  /// class DoIt {}
  ///
  /// DoIt Function() onSchedule(MessageContext, DoItLater) {
  ///   // This function will be called when the schedule elapses to produce a
  ///   // message to post
  ///   return () => DoIt();
  /// }
  /// void onDoIt(MessageContext, DoIt) => print('It was done');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Handle DoItLater message by scheduling a DoIt message to be posted in
  ///   // the future
  ///   b.onMessage<DoItLater>((b) => b.stay(action: b.act.schedule<DoIt>(
  ///     onSchedule,
  ///     duration: Duration(milliseconds: 10))));
  ///   // Handle the DoIt message that was scheduled
  ///   b.onMessage<DoIt>((b) => b.stay(action: b.act.run(onDoIt)));
  /// });
  /// ```
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  _MessageAction<M> schedule<M2>({
    FutureOr<M2 Function()> Function(MessageContext msgCtx, M msg)? getMessage,
    M2? message,
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getValue or value must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getValue or value must be provided');
    }
    var _getMessage = getMessage;
    _getMessage ??= (_, __) => () => message!;

    return _MessageAction<M>._(
      _ActionType.schedule,
      (msgCtx, msg) => _getMessage!(msgCtx, msg).bind(
        (scheduleMsg) {
          _logger.fine(() =>
              "State '$_forState' is scheduling message of type $M2 ${periodic ? 'periodic: true' : ''}");
          msgCtx.schedule(
            scheduleMsg as Object Function(),
            duration: duration,
            periodic: periodic,
          );
        },
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }

  /// Posts a new message to be processed by the state machine while a message is being handled.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the transition occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  /// ```dart
  /// class DoIt {}
  /// class ItWasDone {}
  ///
  /// ItWasDone onDoIt(MessageContext ctx, DoIt msg) {
  ///   print('I did it');
  ///   return ItWasDone();
  /// }
  /// void onItWasDone(MessageContext ctx, ItWasDone msg) => print('It was done');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialState: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Handle DoIt message by posting a ItWasDone message for future processing
  ///   b.onMessage<DoIt>((b) => b.stay(action: b.act.post(onDoIt)));
  ///   // Handle ItWasDone message
  ///   b.onMessage<ItWasDone>((b) => b.stay(action: b.act.run(onItWasDone)));
  /// });
  /// ```
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  _MessageAction<M> post<M2>({
    FutureOr<M2> Function(MessageContext msgCtx, M msg)? getMessage,
    M2? message,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getMessage = getMessage ?? (_, __) => message!;
    return _MessageAction<M>._(
      _ActionType.post,
      (msgCtx, msg) => _getMessage(msgCtx, msg).bind(
        (scheduleMsg) {
          _logger.fine(() => "State '$_forState' is posting message of type $M2");
          msgCtx.post(scheduleMsg as Object);
        },
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}

class _ContinuationMessageAction<M, T> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg, T ctx) _action;
  _ContinuationMessageAction._(
    this.actionType,
    this._action,
    this.postMessageType,
    this.label,
  );

  static FutureOr<void> _empty<M, T>(MessageContext msgCtx, M msg, T ctx) {}
}

class ContinuationMessageActionBuilder<M, T> {
  _ContinuationMessageAction<M, T> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg, T ctx) action, {
    String? label,
  }) {
    return _ContinuationMessageAction<M, T>._(_ActionType.run, action, null, label);
  }

  _ContinuationMessageAction<M, T> updateData<D>(
    D Function(MessageContext msgCtx, M msg, D current, T ctx) update, {
    String? label,
  }) {
    return _ContinuationMessageAction<M, T>._(
      _ActionType.updateData,
      (msgCtx, msg, ctx) {
        msgCtx.dataOrThrow<D>().update((d) => update(msgCtx, msg, d, ctx));
      },
      null,
      label,
    );
  }

  _ContinuationMessageAction<M, T> schedule<M2>(
    FutureOr<Object> Function(MessageContext msgCtx, M msg, T ctx) getMessage, {
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    return _ContinuationMessageAction<M, T>._(
      _ActionType.schedule,
      (msgCtx, msg, ctx) => getMessage(msgCtx, msg, ctx).bind(
        (scheduleMsg) => msgCtx.schedule(
          () => scheduleMsg,
          duration: duration,
          periodic: periodic,
        ),
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}

class _MessageActionWithData<M, D> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg, D data) _action;

  _MessageActionWithData._(this.actionType, this._action, this.postMessageType, this.label);

  static FutureOr<void> _empty<M, D>(MessageContext msgCtx, M msg, D data) {}
}

class MessageActionWithDataBuilder<M, D> {
  final StateKey _forState;
  final _logger = Logger('tree_state_machine.MessageActionWithDataBuilder<$M, $D>');
  MessageActionWithDataBuilder._(this._forState);

  _MessageActionWithData<M, D> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg, D data) action, {
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(_ActionType.run, action, null, label);
  }

  _MessageActionWithData<M, D> updateData(
    D Function(MessageContext msgCtx, M msg, D current) update, {
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(
      _ActionType.updateData,
      (msgCtx, msg, d) {
        msgCtx.dataOrThrow<D>().update((d) => update(msgCtx, msg, d));
      },
      null,
      label,
    );
  }

  _MessageActionWithData<M, D> updateParentData<P>(
    P Function(MessageContext msgCtx, M msg, P current) update, {
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(
      _ActionType.updateData,
      (msgCtx, msg, _) {
        msgCtx.dataOrThrow<P>().update((d) => update(msgCtx, msg, d));
      },
      null,
      label,
    );
  }

  /// Schedules a message to be processed by the state machine while a message is being handled.
  ///
  /// If [getMessage] is provided, the function will be evaluated to produce a message function
  /// which will be called on each scheduling interval to produce the message to post. When
  /// [getMessage] is called, it is provided a [MessageContext], the message that is being
  /// handled, and the current data for the state. If [getMessage] is not provided, then [message]
  /// must be.
  ///
  /// The scheduling will be performed using [TransitionContext.schedule]. Refer to that method
  /// for further details of scheduling semantics.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  _MessageActionWithData<M, D> schedule<M2>({
    FutureOr<M2 Function()> Function(MessageContext msgCtx, M msg, D data)? getMessage,
    M2? message,
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getMessage = getMessage;
    _getMessage ??= (_, __, ___) => () => message!;

    return _MessageActionWithData<M, D>._(
      _ActionType.schedule,
      (msgCtx, msg, data) => _getMessage!(msgCtx, msg, data).bind((scheduleMsg) {
        _logger.fine(() =>
            "State '$_forState' is scheduling message of type $M2: Duration $duration, Periodic: $periodic");
        msgCtx.schedule(
          scheduleMsg as Object Function(),
          duration: duration,
          periodic: periodic,
        );
      }),
      TypeLiteral<M2>().type,
      label,
    );
  }

  /// Posts a new message to be processed by the state machine while a message is being handled.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the transition occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  ///
  /// This action can be labeled when formatting a state tree by providing a [label].
  _MessageActionWithData<M, D> post<M2>({
    FutureOr<M2> Function(MessageContext msgCtx, M msg, D data)? getMessage,
    M2? message,
    String? label,
  }) {
    // TODO: try and combine implementation with post
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }
    var _getMessage = getMessage ?? (_, __, ___) => message!;
    return _MessageActionWithData<M, D>._(
      _ActionType.post,
      (msgCtx, msg, data) => _getMessage(msgCtx, msg, data).bind(
        (scheduleMsg) {
          _logger.fine(() => "State '$_forState' is posting message of type $M2");
          msgCtx.post(scheduleMsg as Object);
        },
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}

class _ContinuationMessageActionWithData<M, D, T> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg, D data, T ctx) _action;
  _ContinuationMessageActionWithData._(
      this.actionType, this._action, this.postMessageType, this.label);

  static FutureOr<void> _empty<M, D, T>(MessageContext msgCtx, M msg, D data, T ctx) {}
}

class ContinuationMessageActionWithDataBuilder<M, D, T> {
  _ContinuationMessageActionWithData<M, D, T> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg, D data, T ctx) action, {
    String? label,
  }) {
    return _ContinuationMessageActionWithData<M, D, T>._(_ActionType.run, action, null, label);
  }

  _ContinuationMessageActionWithData<M, D, T> updateData(
    D Function(MessageContext msgCtx, M msg, D current, T ctx) update, {
    String? label,
  }) {
    return _ContinuationMessageActionWithData<M, D, T>._(
      _ActionType.updateData,
      (msgCtx, msg, data, ctx) {
        msgCtx.dataOrThrow<D>().update((d) => update(msgCtx, msg, d, ctx));
      },
      null,
      label,
    );
  }

  _ContinuationMessageActionWithData<M, D, T> schedule<M2>(
    FutureOr<Object> Function(MessageContext msgCtx, M msg, D data, T ctx) getMessage, {
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    return _ContinuationMessageActionWithData<M, D, T>._(
      _ActionType.schedule,
      (msgCtx, msg, data, ctx) => getMessage(msgCtx, msg, data, ctx).bind(
        (scheduleMsg) => msgCtx.schedule(
          () => scheduleMsg,
          duration: duration,
          periodic: periodic,
        ),
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}
