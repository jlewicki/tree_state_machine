import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/tree_builders.dart';
import './message_handler_descriptor.dart';

MessageHandlerDescriptor<C> makeStayOrUnhandledDescriptor<M, D, C>(
  FutureOr<C> Function(MessageContext) makeContext,
  Logger log,
  StateKey stayInState,
  MessageActionDescriptor<M, D, C>? action,
  String? label,
  String? messageName, {
  required bool handled,
}) {
  var actions = [if (action != null) action.info];
  var handlerType = handled ? MessageHandlerType.stay : MessageHandlerType.unhandled;
  var info = MessageHandlerInfo(handlerType, M, actions, [], messageName, label, {});
  return MessageHandlerDescriptor<C>(
      info,
      makeContext,
      (descrCtx) => (msgCtx) {
            var msg = msgCtx.messageAsOrThrow<M>();
            var data = msgCtx.dataValueOrThrow<D>();
            var handlerCtx = MessageHandlerContext<M, D, C>(msgCtx, msg, data, descrCtx.ctx);
            var action_ = action?.handle ?? (_) {};
            return action_(handlerCtx).bind((_) => handled ? msgCtx.stay() : msgCtx.unhandled());
          });
}
