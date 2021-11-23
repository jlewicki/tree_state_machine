import 'dart:async';

import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makePostDescriptor<C, M, D>(
  FutureOr<M> Function(TransitionContext transCtx, C ctx, D data) getMessage,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.post, [], label, M);
  return TransitionHandlerDescriptor<C>(
    info,
    (ctx) => (transCtx) {
      // TODO: add prop to transCtx that returns the state data of current node?
      var data = transCtx.dataValueOrThrow<D>();
      var msg = getMessage(transCtx, ctx, data).bind((msg) => msg as Object);
      transCtx.post(msg);
    },
  );
}
