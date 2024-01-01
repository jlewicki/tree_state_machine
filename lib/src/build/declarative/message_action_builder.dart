part of '../../../declarative_builders.dart';

/// Provides methods for describing actions that can be taken while a state handles a message.
///
/// A [MessageActionBuilder] is accessed from the [MessageHandlerBuilder.act] property.
///
/// ```dart
/// void onMessage<M>(MessageHandlerContext<M, void, void>) => print('Handling message');
///
/// var state1 = StateKey('s1');
/// var state2 = StateKey('s2');
/// var builder = StateTreeBuilder(initialChild: state1);
///
/// builder.state(state1, (b) {
///   // Calls the onMessage function as a side effect before the transition occurs
///   b.onMessage<MyMessage>((b) => b.goTo(state2, action: b.act.run(onMessage)));
/// });
/// ```
class MessageActionBuilder<M, D, C> {
  final StateKey _forState;
  final Logger _log;

  MessageActionBuilder(this._forState, this._log);

  /// Runs the [action] while a message is being handled.
  ///
  /// When the action function is called, it is passed a [MessageContext], and the message that is
  /// being handled.
  /// ```dart
  /// void onMessage<M>(MessageContext ctx, M message) => print('Handling message');
  ///
  /// var state1 = StateKey('s1');
  /// var state2 = StateKey('s2');
  /// var builder = StateTreeBuilder(initialChild: state1);
  ///
  /// builder.state(state1, (b) {
  ///   // Calls the onMessage function as a side effect before the transition occurs
  ///   b.onMessage<MyMessage>((b) => b.goTo(state2, action: b.act.run(onMessage);
  /// });
  /// ```
  /// This action can be labeled when formatting a state tree by providing a [label].
  MessageActionDescriptor<M, D, C> run(
    FutureOr<void> Function(MessageHandlerContext<M, D, C>) action, {
    String? label,
  }) {
    var info = MessageActionInfo(ActionType.run, null, null, label);
    return MessageActionDescriptor<M, D, C>(info, action);
  }

  /// Updates state data of type [D] while a message is being handled.
  ///
  /// When [update] function is called, it is provided a [MessageHandlerContext], and the current
  /// state data value.
  /// ```dart
  /// enum Messages { increment  }
  /// var countingState = DataStateKey<int>('counting');
  /// var builder = new StateTreeBuilder(initialChild: countingState);
  ///
  /// builder.dataState<int>(
  ///   countingState,
  ///   InitialData.value(1),
  ///   (b) {
  ///     b.onMessageValue<Messages>(Messages.increment, (b) {
  ///       // Updates state data as a side effect while the message is handled.
  ///       b.stay(action: b.act.updateData((ctx, counter) => counter + 1));
  ///     });
  ///   });
  /// ```
  /// This action can be labeled when formatting a state tree by providing a [label].
  MessageActionDescriptor<M, D, C> updateData<D2>(
    DataStateKey<D2> forState,
    D2 Function(MessageHandlerContext<M, D, C> ctx, D2 data) update, {
    String? label,
  }) {
    var info = MessageActionInfo(ActionType.updateData, null, D2, label);
    return MessageActionDescriptor(info, (ctx) {
      _log.fine(() => "State '$_forState' is updating data of type $D2");
      ctx.messageContext
          .data(forState)
          .update((current) => update(ctx, current));
    });
  }

  MessageActionDescriptor<M, D, C> updateOwnData(
    D Function(MessageHandlerContext<M, D, C> ctx) update, {
    String? label,
  }) {
    var info = MessageActionInfo(ActionType.updateData, null, D, label);
    return MessageActionDescriptor(info, (ctx) {
      _log.fine(() => "State '$_forState' is updating data of type $D");
      var data = _forState is DataStateKey<D>
          ? ctx.messageContext.data(_forState)
          : throw StateError(
              'Unable to find data value of type $D in active data states');
      data.update((current) => update(ctx));
    });
  }

  /// Schedules a message to be processed by the state machine while a message is being handled.
  ///
  /// If [getMessage] is provided, the function will be evaluated to produce a message function
  /// which will be called on each scheduling interval to produce the message to post. When
  /// [getMessage] is called, it is provided a [MessageHandlerContext]. If [getMessage] is not
  /// provided, then [message] must be.
  ///
  /// The scheduling will be performed using [TransitionContext.schedule]. Refer to that method
  /// for further details of scheduling semantics.
  ///
  /// ```dart
  /// class DoItLater {}
  /// class DoIt {}
  ///
  /// DoIt onSchedule(MessageHandlerContext<DoItLater, void, void> ctx) {
  ///   // This function will be called when the schedule elapses to produce a
  ///   // message to post
  ///   return DoIt();
  /// }
  /// void onDoIt(MessageContext, DoIt) => print('It was done');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialChild: state1);
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
  MessageActionDescriptor<M, D, C> schedule<M2>({
    FutureOr<M2> Function(MessageHandlerContext<M, D, C> ctx)? getMessage,
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

    var getMessage_ = getMessage ?? (_) => message!;
    var info = MessageActionInfo(ActionType.schedule, M2, null, label);
    return MessageActionDescriptor<M, D, C>(
      info,
      (ctx) => getMessage_(ctx).bind((msg) {
        _log.fine(() =>
            "State '$_forState' is scheduling message of type $M2 ${periodic ? 'periodic: true' : ''}");
        ctx.messageContext.schedule(
          () => msg as Object,
          duration: duration,
          periodic: periodic,
        );
      }),
    );
  }

  /// Posts a new message to be processed by the state machine while a message is being handled.
  ///
  /// If [getMessage] is provided, the function will be evaluated when the transition occurs, and
  /// the returned message will be posted. Otherwise a [message] must be provided.
  ///
  /// ```dart
  /// class DoIt {}
  /// class ItWasDone {}
  ///
  /// ItWasDone onDoIt(MessageHandlerContext<DoItLater, void, void> ctx) {
  ///   print('I did it');
  ///   return ItWasDone();
  /// }
  /// void onItWasDone(MessageContext ctx, ItWasDone msg) => print('It was done');
  ///
  /// var state1 = StateKey('s1');
  /// var builder = StateTreeBuilder(initialChild: state1);
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
  MessageActionDescriptor<M, D, C> post<M2>({
    FutureOr<M2> Function(MessageHandlerContext<M, D, C> ctx)? getMessage,
    M2? message,
    String? label,
  }) {
    if (getMessage == null && message == null) {
      throw ArgumentError('getMessage or message must be provided');
    } else if (getMessage != null && message != null) {
      throw ArgumentError('One of getMessage or message must be provided');
    }

    var getMessage_ = getMessage ?? (_) => message!;
    var info = MessageActionInfo(ActionType.schedule, M2, null, label);
    return MessageActionDescriptor<M, D, C>(
      info,
      (ctx) => getMessage_(ctx).bind((msg) {
        _log.fine(() => "State '$_forState' is posting message of type $M2");
        ctx.messageContext.post(msg as Object);
      }),
    );
  }
}
