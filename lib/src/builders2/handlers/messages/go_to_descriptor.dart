import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './message_handler_descriptor.dart';

MessageHandlerDescriptor<C> makeGoToDescriptor<M, C>(
  StateKey forState,
  StateKey targetState,
  TransitionHandler? transitionAction,
  bool reenterTarget,
  Payload<M, C>? payload,
  MessageActionDescriptor<C>? action,
  String? label,
  String? messageName,
  Logger log,
) {
  var actions = [if (action != null) action.info];
  var info = MessageHandlerInfo(MessageHandlerType.goto, M, actions, [], messageName, label);
  return MessageHandlerDescriptor<C>(
      info,
      (ctx) => (msgCtx) {
            var msg = msgCtx.messageAsOrThrow<M>();
            var _action = action?.makeAction(ctx) ?? (msgCtx) {};
            var _payload = payload ?? emptyDataPayload;
            return _action(msgCtx).bind((_) => _payload(msgCtx, msg, ctx).bind((p) {
                  log.finer(() => "State '$forState' going to state '$targetState'");
                  return msgCtx.goTo(
                    targetState,
                    payload: p,
                    transitionAction: transitionAction,
                    reenterTarget: reenterTarget,
                  );
                }));
          });
}

typedef Payload<M, C> = FutureOr<Object?> Function(MessageContext msgCtx, M msg, C ctx);

FutureOr<Object?> emptyPayload<M>(MessageContext mc, M m) => null;
FutureOr<Object?> emptyDataPayload<M, D>(MessageContext mc, M m, D data) => null;
FutureOr<Object?> emptyContinuationPayload<M, T>(MessageContext mc, M m, T ctx) => null;
FutureOr<Object?> emptyContinuationWithDataPayload<M, D, T>(MessageContext mc, M m, D d, T c) {
  return null;
}
