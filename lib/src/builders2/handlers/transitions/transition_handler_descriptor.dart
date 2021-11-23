import 'dart:async';

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';

enum TransitionHandlerType { run, post, schedule, updateData, channelEntry, when, whenResult }

class TransitionHandlerInfo {
  final TransitionHandlerType handlerType;
  final List<TransitionConditionInfo> conditions;
  final String? label;
  final Type? messageType;

  TransitionHandlerInfo(
    this.handlerType,
    this.conditions,
    this.label, [
    this.messageType,
  ]);
}

class TransitionHandlerDescriptor<C> {
  final TransitionHandlerInfo info;
  // final C Function(TransitionContext)? makeContext;
  //final TransitionHandler Function(TransitionContext transCtx, C ctx) makeHandler;
  final TransitionHandler Function(C ctx) makeHandler;
  //TransitionHandlerDescriptor._(this.info, this.makeContext, this.makeHandler);
  TransitionHandlerDescriptor(this.info, /*this.makeContext,*/ this.makeHandler);

  // factory TransitionHandlerDescriptor.fromTransitionContext(
  //   TransitionHandlerInfo info,
  //   C Function(TransitionContext) makeContext,
  //   final TransitionHandler Function(TransitionContext transCtx, C ctx) makeHandler;
  // ) {
  //   return TransitionHandlerDescriptor._(info, makeContext, makeHandler);
  // }

  // static TransitionHandlerDescriptor<TransitionContext> forTransitionContext(
  //   TransitionHandlerInfo info,
  //   TransitionHandler handler,
  // ) {
  //   return TransitionHandlerDescriptor<TransitionContext>._(
  //     info,
  //     (transCtx) => transCtx,
  //     (_, __) => handler,
  //   );
  // }
}

class TransitionConditionInfo {
  final String? label;
  final TransitionHandlerInfo whenTrueInfo;

  TransitionConditionInfo(this.label, this.whenTrueInfo);
}

typedef TransitionConditionHandler = FutureOr<bool> Function(TransitionContext);

class TransitionConditionDescriptor<C> {
  final TransitionConditionInfo info;
  final TransitionConditionHandler Function(C ctx) makeCondition;
  final TransitionHandlerDescriptor<C> whenTrueDescriptor;

  TransitionConditionDescriptor(this.info, this.makeCondition, this.whenTrueDescriptor);

  static TransitionConditionDescriptor<C> withData<C, D>(
    TransitionConditionInfo info,
    FutureOr<bool> Function(TransitionContext transCtx, C ctx, D data) condition,
    TransitionHandlerDescriptor<C> whenTrue,
  ) {
    return TransitionConditionDescriptor<C>(
      info,
      (ctx) => (transCtx) {
        var data = transCtx.dataValueOrThrow<D>();
        return condition(transCtx, ctx, data);
      },
      whenTrue,
    );
  }
}
