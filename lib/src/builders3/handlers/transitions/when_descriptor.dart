import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/tree_builders3.dart';
import './transition_handler_descriptor.dart';

typedef TransitionCondition<C, D> = FutureOr<bool> Function(
    TransitionContext transCtx, C ctx, D data);

TransitionHandlerDescriptor<C> makeWhenDescriptor<C>(
  List<TransitionConditionDescriptor<C>> conditions,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String? label,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = TransitionHandlerInfo(TransitionHandlerType.when, conditionInfos, label);
  return TransitionHandlerDescriptor<C>(
    info,
    makeContext,
    (ctx) => (transCtx) => _runConditions<C>(conditions.iterator, ctx.ctx, transCtx),
  );
}

TransitionHandlerDescriptor<C> makeWhenWithContextDescriptor<D, C, C2>(
  FutureOr<C2> Function(TransitionHandlerContext<D, C> ctx) context,
  List<TransitionConditionDescriptor<C2>> conditions,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String? label,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = TransitionHandlerInfo(TransitionHandlerType.when, conditionInfos, label);
  return TransitionHandlerDescriptor<C>(
    info,
    makeContext,
    (descrCtx) => (transCtx) {
      var data = transCtx.dataValueOrThrow<D>();
      var ctx = TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
      return context(ctx).bind(
        (newCtx) => _runConditions<C2>(conditions.iterator, newCtx, transCtx),
      );
    },
  );
}

FutureOr<void> _runConditions<C>(
  Iterator<TransitionConditionDescriptor<C>> conditionIterator,
  C ctx,
  TransitionContext transCtx,
) {
  if (conditionIterator.moveNext()) {
    var conditionDescr = conditionIterator.current;
    var condition = conditionDescr.makeCondition(ctx);
    return condition(transCtx).bind((allowed) {
      if (allowed) {
        var handler = conditionDescr.whenTrueDescriptor.makeHandler();
        return handler(transCtx);
      }
      return _runConditions(conditionIterator, ctx, transCtx);
    });
  }
}
