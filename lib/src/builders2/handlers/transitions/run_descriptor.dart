import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeRunDescriptor<C, D>(
  FutureOr<void> Function(TransitionContext transCtx, D data, C ctx) handler,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.run, [], label);
  return TransitionHandlerDescriptor<C>(
      info,
      (ctx) => (transCtx) {
            var data = transCtx.dataValueOrThrow<D>();
            return handler(transCtx, data, ctx);
          });
}
