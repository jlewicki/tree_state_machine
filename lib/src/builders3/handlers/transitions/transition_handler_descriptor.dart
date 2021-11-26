import 'dart:async';

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

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

class TransitionConditionInfo {
  final String? label;
  final TransitionHandlerInfo whenTrueInfo;

  TransitionConditionInfo(this.label, this.whenTrueInfo);
}

/// Provides access to the context for a message handler, including the [MessageContext], the
/// [message] being processed, the state [data], and the context value.
class TransitionHandlerContext<D, C> {
  final TransitionContext transitionContext;
  final D data;
  final C context;
  TransitionHandlerContext(this.transitionContext, this.data, this.context);
}

class TransitionHandlerDescriptor<C> {
  final TransitionHandlerInfo info;
  final FutureOr<C> Function(TransitionContext) makeContext;
  final TransitionHandler Function(TransitionHandlerDescriptorContext<C>) makeHandlerFromContext;

  TransitionHandler makeHandler() {
    return (transCtx) {
      return makeContext(transCtx).bind((ctx) {
        var descrCtx = TransitionHandlerDescriptorContext<C>(transCtx, ctx);
        var handler = makeHandlerFromContext(descrCtx);
        return handler(transCtx);
      });
    };
  }

  TransitionHandlerDescriptor(this.info, this.makeContext, this.makeHandlerFromContext);
}

typedef TransitionConditionHandler = FutureOr<bool> Function(TransitionContext);

class TransitionConditionDescriptor<C> {
  final TransitionConditionInfo info;
  final TransitionConditionHandler Function(C ctx) makeCondition;
  final TransitionHandlerDescriptor<C> whenTrueDescriptor;

  TransitionConditionDescriptor(this.info, this.makeCondition, this.whenTrueDescriptor);

  static TransitionConditionDescriptor<C> withData<D, C>(
    TransitionConditionInfo info,
    FutureOr<bool> Function(TransitionHandlerContext<D, C>) condition,
    TransitionHandlerDescriptor<C> whenTrue,
  ) {
    return TransitionConditionDescriptor<C>(
      info,
      (ctx) => (transCtx) {
        var data = transCtx.dataValueOrThrow<D>();
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




// void example() {
//   var sb = _StateBuilder<int>(StateKey(''));
//   sb.onEnter((b) {
//     b.updateData<String>((transCtx, data, ctx) => data);
//   });

//   TransitionHandler handler = sb._onEnterDescriptor!.makeHandler();
// }
