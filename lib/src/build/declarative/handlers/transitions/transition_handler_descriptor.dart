import 'dart:async';

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/declarative_builders.dart';

enum TransitionHandlerType {
  run,
  post,
  schedule,
  updateData,
  channelEntry,
  when,
  whenResult,
  handler
}

class TransitionHandlerInfo {
  final TransitionHandlerType handlerType;
  final Iterable<TransitionConditionInfo> conditions;
  final String? label;
  final String? postOrScheduleMessageType;
  final Type? updateDataType;

  TransitionHandlerInfo(
    this.handlerType,
    this.conditions,
    this.label, [
    this.postOrScheduleMessageType,
    this.updateDataType,
  ]);
}

class TransitionConditionInfo {
  final String? label;
  final TransitionHandlerInfo whenTrueInfo;

  TransitionConditionInfo(this.label, this.whenTrueInfo);
}

class TransitionHandlerDescriptor<C> {
  final TransitionHandlerInfo info;
  final FutureOr<C> Function(TransitionContext) makeContext;
  final TransitionHandler Function(TransitionHandlerDescriptorContext<C>)
      makeHandlerFromContext;

  TransitionHandler makeHandler() {
    return (transCtx) {
      return makeContext(transCtx).bind((ctx) {
        var descrCtx = TransitionHandlerDescriptorContext<C>(transCtx, ctx);
        var handler = makeHandlerFromContext(descrCtx);
        return handler(transCtx);
      });
    };
  }

  TransitionHandlerDescriptor(
      this.info, this.makeContext, this.makeHandlerFromContext);

  static TransitionHandlerDescriptor<void> ofHandler(
      TransitionHandler handler, String? label) {
    var info = TransitionHandlerInfo(TransitionHandlerType.handler, [], label);
    return TransitionHandlerDescriptor<void>(info, (_) {}, (_) => handler);
  }
}

typedef TransitionConditionHandler = FutureOr<bool> Function(TransitionContext);

class TransitionConditionDescriptor<C> {
  final TransitionConditionInfo info;
  final TransitionConditionHandler Function(C ctx) makeCondition;
  final TransitionHandlerDescriptor<C> whenTrueDescriptor;

  TransitionConditionDescriptor(
      this.info, this.makeCondition, this.whenTrueDescriptor);

  static TransitionConditionDescriptor<C> withData<D, C>(
    StateKey forState,
    TransitionConditionInfo info,
    FutureOr<bool> Function(TransitionHandlerContext<D, C>) condition,
    TransitionHandlerDescriptor<C> whenTrue,
  ) {
    return TransitionConditionDescriptor<C>(
      info,
      (ctx) => (transCtx) {
        var data = forState is DataStateKey<D>
            ? transCtx.dataValueOrThrow(forState)
            : null as D;
        var handlerCtx = TransitionHandlerContext<D, C>(transCtx, data, ctx);
        return condition(handlerCtx);
      },
      whenTrue,
    );
  }
}

class TransitionHandlerDescriptorContext<C> {
  final TransitionContext transCtx;
  final C ctx;
  TransitionHandlerDescriptorContext(this.transCtx, this.ctx);
}
