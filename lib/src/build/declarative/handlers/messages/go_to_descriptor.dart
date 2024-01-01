import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/declarative_builders.dart';
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
  Map<String, Object> metadata,
) {
  metadata = Map.from(metadata);
  var actions = [if (action != null) action.info];
  var info = MessageHandlerInfo(
    MessageHandlerType.goto,
    M,
    actions,
    [],
    messageName,
    label,
    Map.from(metadata),
    targetState,
  );
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
            var payload_ = payload ?? (_) => null;
            return action_(handlerCtx)
                .bind((_) => payload_(handlerCtx).bind((p) {
                      log.finer(() =>
                          "State '$forState' going to state '$targetState'");
                      return msgCtx.goTo(
                        targetState,
                        payload: p,
                        transitionAction: transitionAction,
                        reenterTarget: reenterTarget,
                        metadata: Map.from(info.metadata ?? const {}),
                      );
                    }));
          });
}
