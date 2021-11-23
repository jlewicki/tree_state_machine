import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './transition_handler_descriptor.dart';

typedef TransitionCondition<C, D> = FutureOr<bool> Function(
    TransitionContext transCtx, C ctx, D data);

TransitionHandlerDescriptor<C> makeWhenDescriptor<C>(
  List<TransitionConditionDescriptor<C>> conditions,
  Logger log,
  String? label,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = TransitionHandlerInfo(TransitionHandlerType.when, conditionInfos, label);
  return TransitionHandlerDescriptor<C>(
    info,
    (ctx) => (transCtx) => _runConditions(conditions.iterator, ctx, transCtx),
  );
}

TransitionHandlerDescriptor<C> makeWhenWithContextDescriptor<C, C2>(
  FutureOr<C2> Function(TransitionContext msgCtx, C ctx) context,
  List<TransitionConditionDescriptor<C>> conditions,
  Logger log,
  String? label,
  String? messageName,
) {
  var conditionInfos = conditions.map((e) => e.info).toList();
  var info = TransitionHandlerInfo(TransitionHandlerType.when, conditionInfos, label);
  return TransitionHandlerDescriptor<C>(
    info,
    (ctx) => (transCtx) {
      return context(transCtx, ctx)
          .bind((newCtx) => _runConditions(conditions.iterator, newCtx, transCtx));
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
        var handler = conditionDescr.whenTrueDescriptor.makeHandler(ctx);
        return handler(transCtx);
      }
      return _runConditions(conditionIterator, ctx, transCtx);
    });
  }
}
