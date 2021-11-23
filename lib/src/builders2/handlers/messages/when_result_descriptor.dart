import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/builders2/handlers/messages/message_handler_descriptor.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/tree_builders.dart';

MessageHandlerDescriptor<C> makeWhenResultDescriptor<M, C, T>(
  StateKey forState,
  FutureOr<Result<T>> Function(MessageContext ctx, M message) _result,
  MessageHandlerDescriptor<T> successContinuation,
  Ref<MessageHandlerDescriptor<AsyncError>?> errorContinuationRef,
  Logger log,
  String? label,
  String? messageName,
) {
  var conditionLabel = label != null ? '$label success' : 'success';
  var conditions = [MessageConditionInfo(conditionLabel, successContinuation.info)];
  var descriptorInfo = MessageHandlerInfo(
    MessageHandlerType.whenResult,
    M,
    [],
    conditions,
    messageName,
    label,
  );
  return MessageHandlerDescriptor<C>(
      descriptorInfo,
      (ctx) => (msgCtx) {
            var msg = msgCtx.messageAsOrThrow<M>();
            return _result(msgCtx, msg).bind((result) {
              if (result.isError) {
                var err = result.asError!;
                var asyncErr = AsyncError(err.error, err.stackTrace);
                log.fine("State '$forState' received error result '${asyncErr.error}'");
                if (errorContinuationRef.value != null) {
                  log.finer("Invoking error continuation");
                  var errorHandler = errorContinuationRef.value!.makeHandler(asyncErr);
                  return errorHandler(msgCtx);
                } else {
                  log.finer("Throwing error because no error continuation has been registered");
                  throw asyncErr;
                }
              }
              log.finer("State '$forState' received a success result");
              var successHandler = successContinuation.makeHandler(result.asValue!.value);
              return successHandler(msgCtx);
            });
          });
}
