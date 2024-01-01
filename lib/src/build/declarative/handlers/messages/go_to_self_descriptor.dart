import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import './message_handler_descriptor.dart';

MessageHandlerDescriptor<C> makeGoToSelfDescriptor<M, D, C>(
  StateKey forState,
  FutureOr<C> Function(MessageContext) makeContext,
  Logger log,
  TransitionHandler? transitionAction,
  MessageActionDescriptor<M, D, C>? action,
  String? label,
  String? messageName,
) {
  var actions = [if (action != null) action.info];
  var info = MessageHandlerInfo(
      MessageHandlerType.goto, M, actions, [], messageName, label, {});
  return MessageHandlerDescriptor<C>(
      info,
      makeContext,
      (descrCtx) => (msgCtx) {
            var msg = msgCtx.messageAsOrThrow<M>();
            var data = forState is DataStateKey<D>
                ? msgCtx.dataValueOrThrow(forState)
                : null as D;
            var handlerCtx =
                MessageHandlerContext<M, D, C>(msgCtx, msg, data, descrCtx.ctx);
            var action_ = action?.handle ?? (_) {};
            return action_(handlerCtx).bind(
                (_) => msgCtx.goToSelf(transitionAction: transitionAction));
          });
}
