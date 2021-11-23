import 'dart:async';

import 'package:tree_state_machine/src/machine/tree_state.dart';

enum MessageHandlerType { goto, gotoSelf, stay, when, whenWithContext, whenResult, unhandled }

class MessageHandlerInfo {
  final MessageHandlerType handlerType;
  final Type messageType;
  // In general there is at most 1 action
  final List<MessageActionInfo> actions;
  final List<MessageConditionInfo> conditions;
  final String? messageName;
  final String? label;

  MessageHandlerInfo(
    this.handlerType,
    this.messageType,
    this.actions,
    this.conditions,
    this.messageName,
    this.label,
  );
}

class MessageHandlerDescriptor<C> {
  final MessageHandlerInfo info;
  final MessageHandler Function(C ctx) makeHandler;
  MessageHandlerDescriptor(this.info, this.makeHandler);
}

enum ActionType { schedule, post, updateData, run }

abstract class MessageActionInfo {
  final ActionType actionType;
  final Type? postMessageType;
  final String? label;

  MessageActionInfo(
    this.actionType,
    this.postMessageType,
    this.label,
  );
}

typedef MessageActionHandler = FutureOr<void> Function(MessageContext);

class MessageActionDescriptor<C> {
  final MessageActionInfo info;
  final MessageActionHandler Function(C ctx) makeAction;
  MessageActionDescriptor(this.info, this.makeAction);
  static FutureOr<void> empty<M>(MessageContext msgCtx, M msg) {}
}

class MessageConditionInfo {
  final String? label;
  final MessageHandlerInfo whenTrueInfo;
  MessageConditionInfo(this.label, this.whenTrueInfo);
}

typedef MessageConditionHandler = FutureOr<bool> Function(MessageContext);

class MessageConditionDescriptor<C> {
  final MessageConditionInfo info;
  final MessageConditionHandler Function(C ctx) makeCondition;
  final MessageHandlerDescriptor<C> whenTrueDescriptor;
  MessageConditionDescriptor(this.info, this.makeCondition, this.whenTrueDescriptor);
}

FutureOr<void> emptyAction<M>(MessageContext mc, M m) {}
FutureOr<void> emptyDataAction<M, D>(MessageContext mc, M m, D d) {}
FutureOr<void> emptyContinuationAction<M, T>(MessageContext mc, M n, T c) => null;
FutureOr<void> emptyContinuationActionWithData<M, D, T>(MessageContext mc, M m, D d, T c) => null;
