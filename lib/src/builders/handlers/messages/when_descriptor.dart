import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/tree_builders.dart';
import './message_handler_descriptor.dart';

typedef TransitionCondition<C, D> = FutureOr<bool> Function(
    TransitionContext transCtx, C ctx, D data);

MessageHandlerDescriptor<C> makeWhenMessageDescriptor<M, D, C>(
  List<MessageConditionDescriptor<M, D, C>> conditions,
  FutureOr<C> Function(MessageContext) makeContext,
  Logger log,
  String? label,
  String? messageName,
) {
  // Note lazy evaluation is deliberate here, since conditions can be added to the list after this
  // methos is called.
  var conditionInfos = conditions.map((e) => e.info);
  var info = MessageHandlerInfo(
    MessageHandlerType.when,
    M,
    [],
    conditionInfos,
    messageName,
    label,
    {},
  );
  return MessageHandlerDescriptor<C>(
    info,
    makeContext,
    (descrCtx) => (msgCtx) {
      var msg = msgCtx.messageAsOrThrow<M>();
      var data = msgCtx.dataValueOrThrow<D>();
      var handlerCtx = MessageHandlerContext<M, D, C>(msgCtx, msg, data, descrCtx.ctx);
      return _runConditions<M, D, C>(conditions.iterator, handlerCtx);
    },
  );
}

MessageHandlerDescriptor<C> makeWhenWithContextMessageDescriptor<M, D, C, C2>(
  FutureOr<C2> Function(MessageHandlerContext<M, D, C>) context,
  List<MessageConditionDescriptor<M, D, C2>> conditions,
  FutureOr<C> Function(MessageContext) makeContext,
  Logger log,
  String? label,
  String? messageName,
) {
  // Note lazy evaluation is deliberate here, since conditions can be added to the list after this
  // methos is called.
  var conditionInfos = conditions.map((e) => e.info);
  var info = MessageHandlerInfo(
    MessageHandlerType.when,
    M,
    [],
    conditionInfos,
    messageName,
    label,
    {},
  );
  return MessageHandlerDescriptor<C>(
    info,
    makeContext,
    (descrCtx) => (msgCtx) {
      var msg = msgCtx.messageAsOrThrow<M>();
      var data = msgCtx.dataValueOrThrow<D>();
      var handlerCtx = MessageHandlerContext<M, D, C>(msgCtx, msg, data, descrCtx.ctx);
      return context(handlerCtx).bind((newCtx) {
        var newHandlerCtx = MessageHandlerContext<M, D, C2>(msgCtx, msg, data, newCtx);
        return _runConditions<M, D, C2>(conditions.iterator, newHandlerCtx);
      });
    },
  );
}

FutureOr<MessageResult> _runConditions<M, D, C>(
  Iterator<MessageConditionDescriptor<M, D, C>> conditionIterator,
  MessageHandlerContext<M, D, C> ctx,
) {
  if (conditionIterator.moveNext()) {
    var conditionDescr = conditionIterator.current;
    return conditionDescr.evaluate(ctx).bind((allowed) {
      if (allowed) {
        var handler = conditionDescr.whenTrueDescriptor.makeHandler();
        return handler(ctx.messageContext);
      }
      return _runConditions(conditionIterator, ctx);
    });
  }
  return ctx.messageContext.unhandled();
}
