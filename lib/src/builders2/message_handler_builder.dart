import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/go_to_self_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/stay_or_unhandled_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/when_result_descriptor.dart';
import 'package:tree_state_machine/src/builders2/state_builders.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/go_to_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/message_handler_descriptor.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/when_descriptor.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

/// Describes the message processing result of runnin an action with [MessageHandlerBuilder.action].
enum ActionResult {
  /// The message was handled, and the state machine should stay in the current state.
  handled,

  /// The message was unhandled, and should be dispatched to a parent state for processing.
  unhandled,
}

abstract class _MessageHandlerBuilder<C> {
  final StateKey _forState;
  final Logger _log;
  final String? _messageName;
  MessageHandlerDescriptor<C>? _handler;

  _MessageHandlerBuilder(this._forState, this._log, this._messageName);

  _MessageHandlerBuilder<C> newBuilder();

  MessageHandlerWhenResultBuilder<M, BFailure> _whenResult<
      M,
      T,
      BSuccess extends _MessageHandlerBuilder<T>,
      BFailure extends _MessageHandlerBuilder<AsyncError>>(
    FutureOr<Result<T>> Function(MessageContext msgCtx, M msg) result,
    BSuccess Function() makeSuccessBuilder,
    BFailure Function() makeFailureBuilder,
    void Function(BSuccess) buildTrueHandler, {
    String? label,
  }) {
    var continuationBuilder = makeSuccessBuilder();
    buildTrueHandler(continuationBuilder);
    var successContinuation = continuationBuilder._handler!;

    var refFailure = Ref<MessageHandlerDescriptor<AsyncError>?>(null);
    _handler = makeWhenResultDescriptor<M, C, T>(
      _forState,
      result,
      successContinuation,
      refFailure,
      _log,
      label,
      _messageName,
    );
    return MessageHandlerWhenResultBuilder(
      makeFailureBuilder,
      refFailure,
    );
  }

  MessageHandlerWhenBuilder<M, T, B> _whenWith<M, T, B extends _MessageHandlerBuilder<T>>(
    B Function() makeBuilder,
    FutureOr<T> Function(MessageContext msgCtx, M message, C ctx) context,
    MessageCondition<M, T> condition,
    void Function(B builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = makeBuilder();
    buildTrueHandler(trueBuilder);
    var whenTrueDescr = trueBuilder._handler!;

    var conditionInfo = MessageConditionInfo(label, whenTrueDescr.info);
    var conditions = [
      MessageConditionDescriptor<T>(
        conditionInfo,
        (ctx) => (msgCtx) => condition(msgCtx, msgCtx.messageAsOrThrow<M>(), ctx),
        whenTrueDescr,
      ),
    ];

    _handler = makeWhenWithContextDescriptor<M, C, T>(
      context,
      conditions,
      _log,
      label,
      _messageName,
    );

    return MessageHandlerWhenBuilder<M, T, B>._(
      makeBuilder,
      conditions,
    );
  }
}

mixin _GoToBuilders<M, C> on _MessageHandlerBuilder<C> {
  void goTo(
    StateKey targetState, {
    TransitionHandler? transitionAction,
    Payload<M, C>? payload,
    MessageActionDescriptor<C>? action,
    bool reenterTarget = false,
    String? label,
  }) {
    _handler = makeGoToDescriptor<M, C>(
      _forState,
      targetState,
      transitionAction,
      reenterTarget,
      payload,
      action,
      label,
      _messageName,
      _log,
    );
  }

  void enterChannel<P>(
    Channel<P> channel,
    Payload payload, {
    bool reenterTarget = false,
  }) {
    goTo(channel.to, payload: payload, reenterTarget: reenterTarget);
  }
}

mixin _WhenBuilders<M, C, B extends _MessageHandlerBuilder<C>> on _MessageHandlerBuilder<C> {
  MessageHandlerWhenBuilder<M, C, B> when(
    MessageCondition<M, C> condition,
    void Function(B builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = newBuilder() as B;
    buildTrueHandler(trueBuilder);
    var whenTrueDescr = trueBuilder._handler!;
    var conditionInfo = MessageConditionInfo(label, whenTrueDescr.info);
    var conditions = [
      MessageConditionDescriptor<C>(
        conditionInfo,
        (ctx) => (msgCtx) => condition(msgCtx, msgCtx.messageAsOrThrow<M>(), ctx),
        whenTrueDescr,
      ),
    ];
    _handler = makeWhenDescriptor(conditions, _log, label, _messageName);
    return MessageHandlerWhenBuilder<M, C, B>._(() => newBuilder() as B, conditions);
  }
}

mixin _StayOrUnhandledBuilders<M, C> on _MessageHandlerBuilder<C> {
  void stay({
    MessageActionDescriptor<C>? action,
  }) {
    _handler = makeStayOrUnhandledDescriptor(
      _forState,
      action,
      action?.info.label,
      _messageName,
      _log,
      handled: true,
    );
  }

  void unhandled({
    MessageActionDescriptor<C>? action,
  }) {
    _handler = makeStayOrUnhandledDescriptor(
      _forState,
      action,
      action?.info.label,
      _messageName,
      _log,
      handled: false,
    );
  }

  void goToSelf({
    TransitionHandler? transitionAction,
    MessageActionDescriptor<C>? action,
    String? label,
  }) {
    _handler = makeGoToSelfDescriptor(
      transitionAction,
      action,
      label,
      _messageName,
    );
  }

  void action(
    MessageActionDescriptor<C> action, [
    ActionResult actionResult = ActionResult.handled,
  ]) {
    _handler = makeStayOrUnhandledDescriptor(
      _forState,
      action,
      action.info.label,
      _messageName,
      _log,
      handled: actionResult == ActionResult.handled,
    );
  }
}

class MessageHandlerBuilder<M, C> extends _MessageHandlerBuilder<C>
    with
        _GoToBuilders<M, C>,
        _StayOrUnhandledBuilders<M, C>,
        _WhenBuilders<M, C, MessageHandlerBuilder<M, C>> {
  MessageHandlerBuilder(StateKey forState, Logger log, String? messageName)
      : super(forState, log, messageName);

  @override
  MessageHandlerBuilder<M, C> newBuilder() =>
      MessageHandlerBuilder<M, C>(_forState, _log, _messageName);

  MessageCondition<M, MessageContext> makeCondition(
    FutureOr<bool> Function(MessageContext msgCtx, M msg) condition,
  ) {
    return (msgCtx, msg, _) => condition(msgCtx, msg);
  }

  MessageHandlerWhenBuilder<M, T, MessageHandlerBuilder<M, T>> whenWith<T>(
    FutureOr<T> Function(MessageContext messageContext, M message, C ctx) context,
    MessageCondition<M, T> condition,
    void Function(MessageHandlerBuilder<M, T> builder) buildTrueHandler, {
    String? label,
  }) {
    return _whenWith<M, T, MessageHandlerBuilder<M, T>>(
        () => MessageHandlerBuilder<M, T>(_forState, _log, _messageName),
        context,
        condition,
        buildTrueHandler);
  }

  MessageHandlerWhenResultBuilder<M, MessageHandlerBuilder<M, AsyncError>> whenResult<T>(
    FutureOr<Result<T>> Function(MessageContext msgCtx, M msg) result,
    void Function(MessageHandlerBuilder<M, T>) buildTrueHandler, {
    String? label,
  }) {
    return _whenResult<M, T, MessageHandlerBuilder<M, T>, MessageHandlerBuilder<M, AsyncError>>(
      result,
      () => MessageHandlerBuilder<M, T>(_forState, _log, _messageName),
      () => MessageHandlerBuilder<M, AsyncError>(_forState, _log, _messageName),
      buildTrueHandler,
    );
  }
}

class DataMessageHandlerBuilder<M, D, C> extends _MessageHandlerBuilder<C>
    with
        _GoToBuilders<M, C>,
        _StayOrUnhandledBuilders<M, C>,
        _WhenBuilders<M, C, DataMessageHandlerBuilder<M, D, C>> {
  Payload<M, MessageContext>? makePayload(
    FutureOr<Object?> Function(MessageContext msgCtx, M msg, D data)? payload,
  ) {
    return payload != null
        ? (msgCtx, msg, _) {
            var data = msgCtx.dataValueOrThrow<D>();
            return payload(msgCtx, msg, data);
          }
        : null;
  }

  MessageCondition<M, MessageContext> makeCondition(
    FutureOr<bool> Function(MessageContext msgCtx, M msg, D data) condition,
  ) {
    return (msgCtx, msg, _) => condition(msgCtx, msg, msgCtx.dataValueOrThrow<D>());
  }

  DataMessageHandlerBuilder(StateKey forState, Logger log, String? messageName)
      : super(forState, log, messageName);

  @override
  DataMessageHandlerBuilder<M, D, C> newBuilder() =>
      DataMessageHandlerBuilder<M, D, C>(_forState, _log, _messageName);

  MessageHandlerWhenBuilder<M, T, DataMessageHandlerBuilder<M, D, T>> whenWith<T>(
    FutureOr<T> Function(MessageContext msgCtx, M msg, C ctx) context,
    MessageCondition<M, T> condition,
    void Function(DataMessageHandlerBuilder<M, D, T> builder) buildTrueHandler, {
    String? label,
  }) {
    return _whenWith<M, T, DataMessageHandlerBuilder<M, D, T>>(
        () => DataMessageHandlerBuilder<M, D, T>(_forState, _log, _messageName),
        context,
        condition,
        buildTrueHandler);
  }

  MessageHandlerWhenResultBuilder<M, DataMessageHandlerBuilder<M, D, AsyncError>> whenResult<T>(
    FutureOr<Result<T>> Function(MessageContext msgCtx, M msg, D data) result,
    void Function(DataMessageHandlerBuilder<M, D, T>) buildTrueHandler, {
    String? label,
  }) {
    return _whenResult<M, T, DataMessageHandlerBuilder<M, D, T>,
        DataMessageHandlerBuilder<M, D, AsyncError>>(
      (msgCtx, msg) => result(msgCtx, msg, msgCtx.dataValueOrThrow<D>()),
      () => DataMessageHandlerBuilder<M, D, T>(_forState, _log, _messageName),
      () => DataMessageHandlerBuilder<M, D, AsyncError>(_forState, _log, _messageName),
      buildTrueHandler,
    );
  }
}

class MessageHandlerWhenBuilder<M, C, B extends _MessageHandlerBuilder<C>> {
  final List<MessageConditionDescriptor<C>> _conditions;
  final B Function() _makeBuilder;

  MessageHandlerWhenBuilder._(this._makeBuilder, this._conditions);

  MessageHandlerWhenBuilder<M, C, B> when(
    MessageCondition<M, C> condition,
    void Function(B builder) buildTrueHandler, {
    String? label,
  }) {
    var trueBuilder = _makeBuilder();
    buildTrueHandler(trueBuilder);
    var whenTrueDescr = trueBuilder._handler!;
    var conditionInfo = MessageConditionInfo(label, whenTrueDescr.info);
    _conditions.add(
      MessageConditionDescriptor<C>(
        conditionInfo,
        (ctx) => (msgCtx) => condition(msgCtx, msgCtx.messageAsOrThrow<M>(), ctx),
        whenTrueDescr,
      ),
    );
    return this;
  }

  void otherwise(
    void Function(B builder) buildOtherwise, {
    String? label,
  }) {
    var otherwiseBuilder = _makeBuilder();
    buildOtherwise(otherwiseBuilder);
    var otherwiseDescr = otherwiseBuilder._handler!;
    var conditionInfo = MessageConditionInfo(label, otherwiseDescr.info);
    _conditions.add(
      MessageConditionDescriptor<C>(conditionInfo, (_) => (_) => true, otherwiseDescr),
    );
  }
}

class MessageHandlerWhenResultBuilder<M, B extends _MessageHandlerBuilder<AsyncError>> {
  final Ref<MessageHandlerDescriptor<AsyncError>?> _failureContinuationRef;
  final B Function() _makeBuilder;

  MessageHandlerWhenResultBuilder(this._makeBuilder, this._failureContinuationRef);

  void otherwise(
    void Function(B) buildErrorHandler, {
    String? label,
  }) {
    var errorBuilder = _makeBuilder();
    buildErrorHandler(errorBuilder);
    _failureContinuationRef.value = errorBuilder._handler;
  }
}

class FinalStateInfo {
  final CurrentState finalState;
  FinalStateInfo(this.finalState);
}

// TODO: intead of CurrentStste as type para, use a type witrh a contraint that provides access to
// current param (so we can use whenWith)
class MachineDoneHandlerBuilder<C> extends _MessageHandlerBuilder<C>
    with _GoToBuilders<Object, C>, _WhenBuilders<Object, C, MachineDoneHandlerBuilder<C>> {
  MachineDoneHandlerBuilder(StateKey forState, Logger log, String? messageName)
      : super(forState, log, messageName);

  Payload<Object, FinalStateInfo>? makePayload(
    FutureOr<Object?> Function(MessageContext msgCtx, FinalStateInfo finalState)? payload,
  ) {
    return payload != null ? (msgCtx, msg, finalState) => payload(msgCtx, finalState) : null;
  }

  MessageCondition<Object, FinalStateInfo> makeCondition(
    FutureOr<bool> Function(MessageContext msgCtx, FinalStateInfo finalState) condition,
  ) {
    return (msgCtx, msg, finalState) => condition(msgCtx, finalState);
  }

  MessageHandlerWhenBuilder<Object, T, MachineDoneHandlerBuilder<T>> whenWith<T>(
    FutureOr<T> Function(MessageContext msgCtx, Object msg, C ctx) context,
    MessageCondition<Object, T> condition,
    void Function(MachineDoneHandlerBuilder<T> builder) buildTrueHandler, {
    String? label,
  }) {
    return _whenWith<Object, T, MachineDoneHandlerBuilder<T>>(
        () => MachineDoneHandlerBuilder<T>(_forState, _log, _messageName),
        context,
        condition,
        buildTrueHandler);
  }

  @override
  MachineDoneHandlerBuilder<C> newBuilder() =>
      MachineDoneHandlerBuilder(_forState, _log, _messageName);
}

void example() {
  var builder = MessageHandlerBuilder<String, MessageContext>(StateKey(''), Logger(''), '');
  builder.whenResult<int>((msgCtx, msg) => Result.value(3), (b) {
    b.goTo(StateKey('success'));
  }).otherwise((b) {
    b.goTo(StateKey('error'));
  });

  var dataBuilder =
      DataMessageHandlerBuilder<String, int, MessageContext>(StateKey(''), Logger(''), '');

  var machineDoneBuilder = MachineDoneHandlerBuilder<FinalStateInfo>(StateKey(''), Logger(''), '');

  dataBuilder.goTo(StateKey(''), payload: dataBuilder.makePayload((msgCtx, msg, data) => data));
  dataBuilder.when(dataBuilder.makeCondition((msgCtx, msg, data) => true), (b) {
    b.goTo(StateKey(''));
  });
  machineDoneBuilder.goTo(
    StateKey('name'),
    payload: machineDoneBuilder.makePayload((msgCtx, fs) => fs.finalState.dataValue<int>()),
  );

  machineDoneBuilder
      .when(
        machineDoneBuilder.makeCondition((msgCtx, finalState) => true),
        (b) => b.goTo(StateKey('name')),
      )
      .otherwise((b) => b.goTo(StateKey('name')));

  machineDoneBuilder
      .whenWith<String>(
        (msgCtx, msg, ctx) => 'hi',
        (msgCtx, msg, ctx) => true,
        (b) => b.goTo(StateKey('name')),
      )
      .when((msgCtx, msg, ctx) => false, (b) => b.goTo(StateKey('targetState')))
      .otherwise((b) => b.goTo(StateKey('foo')));

  //machineDoneBuilder.whenResult((msgCtx, msg) => null, () => null, () => null, (p0) { })
}
