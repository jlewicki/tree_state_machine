import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import './message_handler_descriptor.dart';

typedef TransitionCondition<C, D> = FutureOr<bool> Function(
    TransitionContext transCtx, C ctx, D data);

MessageHandlerDescriptor<C> makeWhenDescriptor<M, D, C>(
  List<MessageConditionDescriptor<M, D, C>> conditions,
  FutureOr<C> Function(MessageContext) makeContext,
  Logger log,
  String? label,
  String? messageName,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = MessageHandlerInfo(MessageHandlerType.when, M, [], conditionInfos, messageName, label);
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

// TransitionHandlerDescriptor<C> makeWhenWithContextDescriptor<D, C, C2>(
//   FutureOr<C2> Function(TransitionContext msgCtx, D data, C ctx) context,
//   List<TransitionConditionDescriptor<C2>> conditions,
//   FutureOr<C> Function(TransitionContext) makeContext,
//   Logger log,
//   String? label,
// ) {
//   var conditionInfos = conditions.map((e) => e.info).toList();
//   var info = TransitionHandlerInfo(TransitionHandlerType.when, conditionInfos, label);
//   return TransitionHandlerDescriptor<C>(
//     info,
//     makeContext,
//     (ctx) => (transCtx) {
//       var data = transCtx.dataValueOrThrow<D>();
//       return context(transCtx, data, ctx.ctx).bind(
//         (newCtx) => _runConditions<C2>(conditions.iterator, newCtx, transCtx),
//       );
//     },
//   );
// }

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
