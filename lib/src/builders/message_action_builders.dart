part of tree_builders;

enum _ActionType {
  schedule,
  post,
  updateData,
  run,
}

abstract class _MessageActionInfo {
  _ActionType get actionType;
  String? get label;
  Type? get postMessageType;
}

class _MessageAction<M> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg) _action;

  _MessageAction._(this.actionType, this._action, this.postMessageType, this.label);

  static FutureOr<void> _empty<M>(MessageContext msgCtx, M msg) {}
}

class MessageActionBuilder<M> {
  _MessageAction<M> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg) action, {
    String? label,
  }) {
    return _MessageAction<M>._(_ActionType.run, action, null, label);
  }

  _MessageAction<M> updateData<D>(
    D Function(MessageContext msgCtx, M msg, D current) update, {
    StateKey? forState,
    String? label,
  }) {
    return _MessageAction<M>._(
      _ActionType.updateData,
      (msgCtx, msg) {
        msgCtx.dataOrThrow<D>(forState).update((d) => update(msgCtx, msg, d));
      },
      null,
      label,
    );
  }

  _MessageAction<M> schedule<M2>(
    FutureOr<M2> Function(MessageContext msgCtx, M msg) getMessage, {
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    return _MessageAction<M>._(
      _ActionType.schedule,
      (msgCtx, msg) => getMessage(msgCtx, msg).bind(
        (scheduleMsg) => msgCtx.schedule(
          () => scheduleMsg as Object,
          duration: duration,
          periodic: periodic,
        ),
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }

  _MessageAction<M> post<M2>(
    FutureOr<Object> Function(MessageContext msgCtx, M msg) getMessage, {
    String? label,
  }) {
    return _MessageAction<M>._(
      _ActionType.post,
      (msgCtx, msg) => getMessage(msgCtx, msg).bind(
        (scheduleMsg) => msgCtx.post(() => scheduleMsg),
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}

class _ContinuationMessageAction<M, T> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg, T ctx) _action;
  _ContinuationMessageAction._(
    this.actionType,
    this._action,
    this.postMessageType,
    this.label,
  );

  static FutureOr<void> _empty<M, T>(MessageContext msgCtx, M msg, T ctx) {}
}

class ContinuationMessageActionBuilder<M, T> {
  _ContinuationMessageAction<M, T> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg, T ctx) action, {
    String? label,
  }) {
    return _ContinuationMessageAction<M, T>._(_ActionType.run, action, null, label);
  }

  _ContinuationMessageAction<M, T> updateData<D>(
    D Function(MessageContext msgCtx, M msg, D current, T ctx) update, {
    String? label,
  }) {
    return _ContinuationMessageAction<M, T>._(
      _ActionType.updateData,
      (msgCtx, msg, ctx) {
        msgCtx.dataOrThrow<D>().update((d) => update(msgCtx, msg, d, ctx));
      },
      null,
      label,
    );
  }

  _ContinuationMessageAction<M, T> schedule<M2>(
    FutureOr<Object> Function(MessageContext msgCtx, M msg, T ctx) getMessage, {
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    return _ContinuationMessageAction<M, T>._(
      _ActionType.schedule,
      (msgCtx, msg, ctx) => getMessage(msgCtx, msg, ctx).bind(
        (scheduleMsg) => msgCtx.schedule(
          () => scheduleMsg,
          duration: duration,
          periodic: periodic,
        ),
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}

class _MessageActionWithData<M, D> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg, D data) _action;

  _MessageActionWithData._(this.actionType, this._action, this.postMessageType, this.label);

  static FutureOr<void> _empty<M, D>(MessageContext msgCtx, M msg, D data) {}
}

class MessageActionWithDataBuilder<M, D> {
  _MessageActionWithData<M, D> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg, D data) action, {
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(_ActionType.run, action, null, label);
  }

  _MessageActionWithData<M, D> updateData(
    D Function(MessageContext msgCtx, M msg, D current) update, {
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(
      _ActionType.updateData,
      (msgCtx, msg, d) {
        msgCtx.dataOrThrow<D>().update((d) => update(msgCtx, msg, d));
      },
      null,
      label,
    );
  }

  _MessageActionWithData<M, D> updateParentData<P>(
    P Function(MessageContext msgCtx, M msg, P current) update, {
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(
      _ActionType.updateData,
      (msgCtx, msg, _) {
        msgCtx.dataOrThrow<P>().update((d) => update(msgCtx, msg, d));
      },
      null,
      label,
    );
  }

  _MessageActionWithData<M, D> schedule<M2>(
    FutureOr<Object> Function(MessageContext msgCtx, M msg, D data) getMessage, {
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    return _MessageActionWithData<M, D>._(
      _ActionType.schedule,
      (msgCtx, msg, data) => getMessage(msgCtx, msg, data).bind((scheduleMsg) => msgCtx.schedule(
            () => scheduleMsg,
            duration: duration,
            periodic: periodic,
          )),
      TypeLiteral<M2>().type,
      label,
    );
  }
}

class _ContinuationMessageActionWithData<M, D, T> implements _MessageActionInfo {
  @override
  final _ActionType actionType;
  @override
  final String? label;
  @override
  final Type? postMessageType;
  final FutureOr<void> Function(MessageContext msgCtx, M msg, D data, T ctx) _action;
  _ContinuationMessageActionWithData._(
      this.actionType, this._action, this.postMessageType, this.label);

  static FutureOr<void> _empty<M, D, T>(MessageContext msgCtx, M msg, D data, T ctx) {}
}

class ContinuationMessageActionWithDataBuilder<M, D, T> {
  _ContinuationMessageActionWithData<M, D, T> run(
    FutureOr<void> Function(MessageContext msgCtx, M msg, D data, T ctx) action, {
    String? label,
  }) {
    return _ContinuationMessageActionWithData<M, D, T>._(_ActionType.run, action, null, label);
  }

  _ContinuationMessageActionWithData<M, D, T> updateData(
    D Function(MessageContext msgCtx, M msg, D current, T ctx) update, {
    String? label,
  }) {
    return _ContinuationMessageActionWithData<M, D, T>._(
      _ActionType.updateData,
      (msgCtx, msg, data, ctx) {
        msgCtx.dataOrThrow<D>().update((d) => update(msgCtx, msg, d, ctx));
      },
      null,
      label,
    );
  }

  _ContinuationMessageActionWithData<M, D, T> schedule<M2>(
    FutureOr<Object> Function(MessageContext msgCtx, M msg, D data, T ctx) getMessage, {
    Duration duration = Duration.zero,
    bool periodic = false,
    String? label,
  }) {
    return _ContinuationMessageActionWithData<M, D, T>._(
      _ActionType.schedule,
      (msgCtx, msg, data, ctx) => getMessage(msgCtx, msg, data, ctx).bind(
        (scheduleMsg) => msgCtx.schedule(
          () => scheduleMsg,
          duration: duration,
          periodic: periodic,
        ),
      ),
      TypeLiteral<M2>().type,
      label,
    );
  }
}
