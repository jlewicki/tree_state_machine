import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/tree_builders3.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeRunDescriptor<D, C>(
  FutureOr<void> Function(TransitionHandlerContext<D, C> ctx) handler,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.run, [], label);
  return TransitionHandlerDescriptor<C>(
      info,
      makeContext,
      (descrCtx) => (transCtx) {
            var data = transCtx.dataValueOrThrow<D>();
            var ctx = TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
            return handler(ctx);
          });
}
