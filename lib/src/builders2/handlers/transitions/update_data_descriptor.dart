import 'package:logging/logging.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/extensions.dart';
import './transition_handler_descriptor.dart';

TransitionHandlerDescriptor<C> makeUpdateDataDescriptor<C, D>(
  D Function(TransitionContext transCtx, D data, C ctx) update,
  StateKey? state,
  Logger log,
  String? label,
) {
  var info = TransitionHandlerInfo(TransitionHandlerType.updateData, [], label);
  return TransitionHandlerDescriptor<C>(
    info,
    (ctx) => (transCtx) {
      var data = transCtx.dataOrThrow<D>(state);
      data.update((d) => update(transCtx, d, ctx));
    },
  );
}
