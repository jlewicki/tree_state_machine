import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import './message_handler_descriptor.dart';

MessageHandlerDescriptor<C> makeWhenResultMessageDescriptor<M, D, C, T>(
  StateKey forState,
  FutureOr<Result<T>> Function(MessageHandlerContext<M, D, C>) result,
  FutureOr<C> Function(MessageContext) makeContext,
  Ref<Result<T>?> resultRef,
  MessageHandlerDescriptor<T> successDescriptor,
  Ref<MessageHandlerDescriptor<AsyncError>?> errorDescriptorRef,
  Logger log,
  String? label,
  String? messageName,
) {
  var conditionLabel = label != null ? '$label success' : 'success';
  var conditions = [
    MessageConditionInfo(conditionLabel, successDescriptor.info)
  ];
  var descriptorInfo = MessageHandlerInfo(
    MessageHandlerType.whenResult,
    M,
    [],
    conditions,
    messageName,
    label,
    {},
  );

  return MessageHandlerDescriptor<C>(
      descriptorInfo,
      makeContext,
      (descrCtx) => (msgCtx) {
            var msg = msgCtx.messageAsOrThrow<M>();
            var data = forState is DataStateKey<D>
                ? msgCtx.data(forState).value
                : null as D;
            var handlerCtx =
                MessageHandlerContext<M, D, C>(msgCtx, msg, data, descrCtx.ctx);
            return result(handlerCtx).bind((result) {
              resultRef.value = result;
              if (result.isError) {
                log.fine(
                    "State '$forState' received error result '${result.asError!.error}'");
                if (errorDescriptorRef.value != null) {
                  log.finer("Invoking error continuation");
                  var errorHandler = errorDescriptorRef.value!.makeHandler();
                  return errorHandler(msgCtx);
                } else {
                  log.finer(
                      "Throwing error because no error continuation has been registered");
                  var err = result.asError!;
                  throw AsyncError(err.error, err.stackTrace);
                }
              } else {
                log.finer("State '$forState' received a success result");
                var successHandler = successDescriptor.makeHandler();
                return successHandler(msgCtx);
              }
            });
          });
}
