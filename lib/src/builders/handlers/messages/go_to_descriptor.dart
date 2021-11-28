import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/tree_builders.dart';
import './message_handler_descriptor.dart';

MessageHandlerDescriptor<C> makeGoToDescriptor<M, D, C>(
  FutureOr<C> Function(MessageContext) makeContext,
  Logger log,
  StateKey forState,
  StateKey targetState,
  TransitionHandler? transitionAction,
  bool reenterTarget,
  FutureOr<Object?> Function(MessageHandlerContext<M, D, C>)? payload,
  MessageActionDescriptor<M, D, C>? action,
  String? label,
  String? messageName,
) {
  var actions = [if (action != null) action.info];
  var info = MessageHandlerInfo(
    MessageHandlerType.goto,
    M,
    actions,
    [],
    messageName,
    label,
    targetState,
  );
  return MessageHandlerDescriptor<C>(
      info,
      makeContext,
      (descrCtx) => (msgCtx) {
            var msg = msgCtx.messageAsOrThrow<M>();
            var data = msgCtx.dataValueOrThrow<D>();
            var handlerCtx = MessageHandlerContext<M, D, C>(msgCtx, msg, data, descrCtx.ctx);
            var _action = action?.handle ?? (_) {};
            var _payload = payload ?? (_) => null;
            return _action(handlerCtx).bind((_) => _payload(handlerCtx).bind((p) {
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

// FutureOr<Object?> emptyPayload<M>(MessageContext mc, M m) => null;
// FutureOr<Object?> emptyDataPayload<M, D>(MessageContext mc, M m, D data) => null;
// FutureOr<Object?> emptyContinuationPayload<M, T>(MessageContext mc, M m, T ctx) => null;
// FutureOr<Object?> emptyContinuationWithDataPayload<M, D, T>(MessageContext mc, M m, D d, T c) {
//   return null;
// }
