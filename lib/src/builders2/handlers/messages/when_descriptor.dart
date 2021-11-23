import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/message_handler_descriptor.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';

typedef MessageCondition<M, C> = FutureOr<bool> Function(MessageContext msgCtx, M msg, C ctx);

MessageHandlerDescriptor<C> makeWhenDescriptor<M, C>(
  List<MessageConditionDescriptor<C>> conditions,
  Logger log,
  String? label,
  String? messageName,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = MessageHandlerInfo(MessageHandlerType.when, M, [], conditionInfos, messageName, label);
  return MessageHandlerDescriptor<C>(
    info,
    (ctx) => (msgCtx) => _runConditions(conditions.iterator, ctx, msgCtx),
  );
}

MessageHandlerDescriptor<C> makeWhenWithContextDescriptor<M, C, T>(
  FutureOr<T> Function(MessageContext msgCtx, M message, C ctx) context,
  List<MessageConditionDescriptor<T>> conditions,
  Logger log,
  String? label,
  String? messageName,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = MessageHandlerInfo(
      MessageHandlerType.whenWithContext, M, [], conditionInfos, messageName, label);
  return MessageHandlerDescriptor<C>(
    info,
    (ctx) => (msgCtx) {
      var msg = msgCtx.messageAsOrThrow<M>();
      return context(msgCtx, msg, ctx)
          .bind((newCtx) => _runConditions(conditions.iterator, newCtx, msgCtx));
    },
  );
}

FutureOr<MessageResult> _runConditions<C>(
  Iterator<MessageConditionDescriptor<C>> conditionIterator,
  C ctx,
  MessageContext msgCtx,
) {
  if (!conditionIterator.moveNext()) return msgCtx.unhandled();

  var conditionDescr = conditionIterator.current;
  var condition = conditionDescr.makeCondition(ctx);
  return condition(msgCtx).bind((allowed) {
    if (allowed) {
      var handler = conditionDescr.whenTrueDescriptor.makeHandler(ctx);
      return handler(msgCtx);
    }
    return _runConditions(conditionIterator, ctx, msgCtx);
  });
}
