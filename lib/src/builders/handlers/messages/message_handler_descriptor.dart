part of tree_builders;

enum _MessageHandlerType { goto, gotoSelf, stay, when, whenWithContext, whenResult, unhandled }

abstract class _MessageHandlerInfo {
  _MessageHandlerType get handlerType;
  Type get messageType;
  String? get messageName;
  String? get label;
  List<_MessageActionInfo> get actions;
}

abstract class _MessageHandlerDescriptor extends _MessageHandlerInfo {
  MessageHandler get handler;

  StateKey? tryGetTargetState() {
    return handlerType == _MessageHandlerType.goto ? (this as _GoToDescriptor).targetState : null;
  }

  List<_MessageConditionInfo>? tryGetConditions() {
    switch (handlerType) {
      case _MessageHandlerType.when:
        return (this as _WhenDescriptor).conditions;
      case _MessageHandlerType.whenWithContext:
        return (this as _WhenWithContextDescriptor).conditions;
      case _MessageHandlerType.whenResult:
        return (this as _WhenResultDescriptor).conditions;
      default:
        return null;
    }
  }

  bool isConditional() {
    switch (handlerType) {
      case _MessageHandlerType.when:
      case _MessageHandlerType.whenResult:
      case _MessageHandlerType.whenWithContext:
        return true;
      default:
        return false;
    }
  }
}

abstract class _ContinuationMessageHandlerDescriptor<T> extends _MessageHandlerInfo {
  MessageHandler Function(T ctx) get continuation;
}

abstract class _GoToInfo {
  StateKey get targetState;
}

FutureOr<void> _emptyAction<M>(MessageContext mc, M m) {}
FutureOr<void> _emptyDataAction<M, D>(MessageContext mc, M m, D d) {}
FutureOr<void> _emptyContinuationAction<M, T>(MessageContext mc, M n, T c) => null;
FutureOr<void> _emptyContinuationActionWithData<M, D, T>(MessageContext mc, M m, D d, T c) => null;

FutureOr<Object?> _emptyPayload<M>(MessageContext mc, M m) => null;
FutureOr<Object?> _emptyDataPayload<M, D>(MessageContext mc, M m, D data) => null;
FutureOr<Object?> _emptyContinuationPayload<M, T>(MessageContext mc, M m, T ctx) => null;
FutureOr<Object?> _emptyContinuationWithDataPayload<M, D, T>(MessageContext mc, M m, D d, T c) {
  return null;
}
