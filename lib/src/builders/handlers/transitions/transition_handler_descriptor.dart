part of tree_builders;

enum _TransitionHandlerType {
  run,
  post,
  schedule,
  updateData,
  channelEntry,
  when,
}

class _TransitionHandlerDescriptor {
  final _TransitionHandlerType handlerType;
  String? label;
  TransitionHandler _handler;

  _TransitionHandlerDescriptor(this.handlerType, this._handler, this.label);

  factory _TransitionHandlerDescriptor.run(TransitionHandler handler, String? label) {
    return _TransitionHandlerDescriptor(_TransitionHandlerType.run, handler, label);
  }

  static _TransitionHandlerDescriptor updateData<D>(
    D Function(TransitionContext transCtx, D current) update,
    StateKey? key,
    String? label,
  ) {
    return _UpdateDataTransitionHandlerDescriptor(
      TypeLiteral<D>().type,
      (transCtx) {
        var data = transCtx.dataOrThrow<D>(key);
        data.update((d) => update(transCtx, d));
      },
      label,
    );
  }

  static _TransitionHandlerDescriptor schedule<M>(
    M Function(TransitionContext ctx) getValue,
    Duration duration,
    bool periodic,
    String? label,
  ) {
    return _PostOrScheduleTransitionHandlerDescriptor(
      _TransitionHandlerType.schedule,
      TypeLiteral<M>().type,
      (transCtx) {
        transCtx.schedule(() => getValue(transCtx) as Object,
            duration: duration, periodic: periodic);
      },
      label,
    );
  }

  static _TransitionHandlerDescriptor post<M>(
    M Function(TransitionContext ctx) getValue,
    String? label,
  ) {
    return _PostOrScheduleTransitionHandlerDescriptor(
      _TransitionHandlerType.post,
      TypeLiteral<M>().type,
      (transCtx) {
        transCtx.post(getValue(transCtx) as Object);
      },
      label,
    );
  }
}

class _PostOrScheduleTransitionHandlerDescriptor extends _TransitionHandlerDescriptor {
  final Type _messageType;
  _PostOrScheduleTransitionHandlerDescriptor(
      _TransitionHandlerType type, this._messageType, TransitionHandler handler, String? label)
      : super(type, handler, label);
}

class _UpdateDataTransitionHandlerDescriptor extends _TransitionHandlerDescriptor {
  final Type _dataType;
  _UpdateDataTransitionHandlerDescriptor(this._dataType, TransitionHandler handler, String? label)
      : super(_TransitionHandlerType.updateData, handler, label);
}
