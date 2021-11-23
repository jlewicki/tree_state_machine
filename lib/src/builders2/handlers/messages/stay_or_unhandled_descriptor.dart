import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './message_handler_descriptor.dart';

MessageHandlerDescriptor<C> makeStayOrUnhandledDescriptor<M, C>(
  StateKey stayInState,
  MessageActionDescriptor<C>? action,
  String? label,
  String? messageName,
  Logger log, {
  required bool handled,
}) {
  var actions = [if (action != null) action.info];
  var info = MessageHandlerInfo(MessageHandlerType.goto, M, actions, [], messageName, label);
  return MessageHandlerDescriptor<C>(
      info,
      (ctx) => (msgCtx) {
            var _action = action?.makeAction(ctx) ?? (msgCtx) {};
            return _action(msgCtx).bind((_) => handled ? msgCtx.stay() : msgCtx.unhandled());
          });
}
