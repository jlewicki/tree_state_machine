import 'dart:async';

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/tree_builders.dart';

enum MessageHandlerType {
  goto,
  gotoSelf,
  stay,
  when,
  whenWithContext,
  whenResult,
  unhandled,
  handler
}

class MessageHandlerInfo {
  final MessageHandlerType handlerType;
  final Type messageType;
  // In general there is at most 1 action
  final List<MessageActionInfo> actions;
  final Iterable<MessageConditionInfo> conditions;
  final String? _messageName;
  final String? label;
  final StateKey? goToTarget;

  MessageHandlerInfo(
    this.handlerType,
    this.messageType,
    this.actions,
    this.conditions,
    this._messageName,
    this.label, [
    this.goToTarget,
  ]);

  String get messageName => _messageName ?? messageType.toString();
}

enum ActionType { schedule, post, updateData, run }

class MessageActionInfo {
  final ActionType actionType;
  final Type? postMessageType;
  final Type? updateDataType;
  final String? label;

  MessageActionInfo(
    this.actionType,
    this.postMessageType,
    this.updateDataType,
    this.label,
  );
}

class MessageConditionInfo {
  final String? label;
  final MessageHandlerInfo whenTrueInfo;
  MessageConditionInfo(this.label, this.whenTrueInfo);
}

class MessageHandlerDescriptorContext<C> {
  final MessageContext msgCtx;
  final C ctx;
  MessageHandlerDescriptorContext(this.msgCtx, this.ctx);
}

class MessageHandlerDescriptor<C> {
  final MessageHandlerInfo info;
  final FutureOr<C> Function(MessageContext) makeContext;
  final MessageHandler Function(MessageHandlerDescriptorContext<C>) makeHandlerFromContext;

  MessageHandlerDescriptor(this.info, this.makeContext, this.makeHandlerFromContext);

  MessageHandler makeHandler() {
    return (msgCtx) {
      return makeContext(msgCtx).bind((ctx) {
        var descrCtx = MessageHandlerDescriptorContext<C>(msgCtx, ctx);
        var handler = makeHandlerFromContext(descrCtx);
        return handler(msgCtx);
      });
    };
  }
}

typedef MessageActionHandler = FutureOr<void> Function(MessageContext);

class MessageActionDescriptor<M, D, C> {
  final MessageActionInfo info;
  final FutureOr<void> Function(MessageHandlerContext<M, D, C>) handle;

  MessageActionDescriptor(this.info, this.handle);
}

typedef MessageConditionHandler = FutureOr<bool> Function(MessageContext);

class MessageConditionDescriptor<M, D, C> {
  final MessageConditionInfo info;
  final MessageHandlerDescriptor<C> whenTrueDescriptor;
  final FutureOr<bool> Function(MessageHandlerContext<M, D, C>) evaluate;

  MessageConditionDescriptor(this.info, this.evaluate, this.whenTrueDescriptor);
}
