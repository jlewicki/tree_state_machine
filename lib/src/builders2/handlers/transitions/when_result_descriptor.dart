import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeWhenResultDescriptor<C, D, T>(
  StateKey forState,
  FutureOr<Result<T>> Function(TransitionContext transCtx, D data, C ctx) _result,
  TransitionHandlerDescriptor<T> successContinuation,
  Ref<TransitionHandlerDescriptor<AsyncError>?> errorContinuationRef,
  Logger log,
  String? label,
) {
  var conditionLabel = label != null ? '$label success' : 'success';
  var conditions = [TransitionConditionInfo(conditionLabel, successContinuation.info)];
  var descriptorInfo = TransitionHandlerInfo(
    TransitionHandlerType.whenResult,
    conditions,
    label,
  );
  return TransitionHandlerDescriptor<C>(
      descriptorInfo,
      (ctx) => (transCtx) {
            var data = transCtx.dataValueOrThrow<D>();
            return _result(transCtx, data, ctx).bind((result) {
              if (result.isError) {
                var err = result.asError!;
                var asyncErr = AsyncError(err.error, err.stackTrace);
                log.fine("State '$forState' received error result '${asyncErr.error}'");
                if (errorContinuationRef.value != null) {
                  log.finer("Invoking error continuation");
                  var errorHandler = errorContinuationRef.value!.makeHandler(asyncErr);
                  return errorHandler(transCtx);
                } else {
                  log.finer("Throwing error because no error continuation has been registered");
                  throw asyncErr;
                }
              }
              log.finer("State '$forState' received a success result");
              var successHandler = successContinuation.makeHandler(result.asValue!.value);
              return successHandler(transCtx);
            });
          });
}
