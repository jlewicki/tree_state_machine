import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import 'package:tree_state_machine/tree_builders.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makePostDescriptor<D, C, M>(
  FutureOr<M> Function(TransitionHandlerContext<D, C> ctx) getMessage,
  FutureOr<C> Function(TransitionContext) makeContext,
  Logger log,
  String messageType,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.post, [], label, messageType);
  return TransitionHandlerDescriptor<C>(
    info,
    makeContext,
    (descrCtx) => (transCtx) {
      var data = transCtx.dataValueOrThrow<D>();
      var ctx = TransitionHandlerContext<D, C>(transCtx, data, descrCtx.ctx);
      var msg = getMessage(ctx).bind((msg) => msg as Object);
      transCtx.post(msg);
    },
  );
}
