import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeScheduleDescriptor<C, M, D>(
  M Function(TransitionContext transCtx, C ctx, D data) getValue,
  Duration duration,
  bool periodic,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.schedule, [], label);
  return TransitionHandlerDescriptor<C>(
    info,
    (ctx) => (transCtx) {
      // TODO: reconsider getMessage. It probably shouldnt accept a transCtx, or alternatively
      // the function passed to schedule  shoyuld accept a transCtx (which should be OK since the
      // timer is cancelled when state is exited)
      var data = transCtx.dataValueOrThrow<D>();
      var msg = getValue(transCtx, ctx, data).bind((msg) => msg as Object);
      transCtx.schedule(() => msg, duration: duration, periodic: periodic);
    },
  );
}
