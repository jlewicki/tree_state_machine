import 'dart:async';

import 'package:async/async.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/declarative_builders.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeWhenResultTransitionDescriptor<C, D, T>(
  StateKey forState,
  FutureOr<Result<T>> Function(TransitionHandlerContext<D, C>) result,
  FutureOr<C> Function(TransitionContext) makeContext,
  Ref<Result<T>?> resultRef,
  TransitionHandlerDescriptor<T> successDescriptor,
  Ref<TransitionHandlerDescriptor<AsyncError>?> errorDescriptorRef,
  Logger log,
  String? label,
) {
  var conditionLabel = label != null ? '$label success' : 'success';
  var conditions = [
    TransitionConditionInfo(conditionLabel, successDescriptor.info)
  ];
  var descriptorInfo = TransitionHandlerInfo(
    TransitionHandlerType.whenResult,
    conditions,
    label,
  );

  return TransitionHandlerDescriptor<C>(
      descriptorInfo,
      makeContext,
      (descrCtx) => (transCtx) {
            var data = forState is DataStateKey<D>
                ? transCtx.dataValueOrThrow(forState)
                : null as D;
            var ctx =
                TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
            return result(ctx).bind((result) {
              resultRef.value = result;
              if (result.isError) {
                log.fine(
                    "State '$forState' received error result '${result.asError!.error}'");
                if (errorDescriptorRef.value != null) {
                  log.finer("Invoking error continuation");
                  var errorHandler = errorDescriptorRef.value!.makeHandler();
                  return errorHandler(transCtx);
                } else {
                  log.finer(
                      "Throwing error because no error continuation has been registered");
                  var err = result.asError!;
                  throw AsyncError(err.error, err.stackTrace);
                }
              } else {
                log.finer("State '$forState' received a success result");
                var successHandler = successDescriptor.makeHandler();
                return successHandler(transCtx);
              }
            });
          });
}
