import 'dart:async';

import 'package:rxdart/rxdart.dart';

import 'data_provider.dart';
import 'tree_state.dart';
import 'utility.dart';

/// A [TreeState] that always returns [MessageContext.unhandled].
class EmptyTreeState extends TreeState {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => context.unhandled();
}

/// A [DataTreeState] that always returns [MessageContext.unhandled].
class EmptyDataTreeState<D> extends DataTreeState<D> {
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => context.unhandled();
}

/// A [TreeState] that delegates its behavior to one or more external functions.
class DelegateState extends TreeState {
  TransitionHandler entryHandler;
  TransitionHandler exitHandler;
  MessageHandler messageHandler;

  DelegateState({this.entryHandler, this.exitHandler, this.messageHandler}) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
    exitHandler = exitHandler ?? emptyTransitionHandler;
    messageHandler = messageHandler ?? emptyMessageHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext context) => entryHandler(context);
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => messageHandler(context);
  @override
  FutureOr<void> onExit(TransitionContext context) => exitHandler(context);
}

/// A [DataTreeState] that delegates its behavior to one or more external functions.
class DelegateDataState<D> extends DataTreeState<D> {
  TransitionHandler entryHandler;
  TransitionHandler exitHandler;
  MessageHandler messageHandler;

  DelegateDataState({
    this.entryHandler,
    this.exitHandler,
    this.messageHandler,
  }) {
    entryHandler = entryHandler ?? emptyTransitionHandler;
    exitHandler = exitHandler ?? emptyTransitionHandler;
    messageHandler = messageHandler ?? emptyMessageHandler;
  }
  @override
  FutureOr<void> onEnter(TransitionContext context) => entryHandler(context);
  @override
  FutureOr<MessageResult> onMessage(MessageContext context) => messageHandler(context);
  @override
  FutureOr<void> onExit(TransitionContext context) => exitHandler(context);
}

/// A [FinalTreeState] that delegates its behavior to an external function.
class DelegateFinalState extends FinalTreeState {
  final TransitionHandler _entryHandler;

  /// Constructs a [DelegateFinalState] that delegates its [onEnter] implementation to
  /// [entryHandler].
  DelegateFinalState([TransitionHandler entryHandler])
      : _entryHandler = entryHandler ?? emptyTransitionHandler;

  @override
  FutureOr<void> onEnter(TransitionContext context) => _entryHandler(context);
}

/// An [ObservableData] that delegates its behavior to external functions.
class DelegateObservableData<D> extends ObservableData<D> {
  Lazy<BehaviorSubject<D>> _lazySubject;

  /// Constructs a [DelegateObservableData] that calls [getData] and [createStream] to obtain its
  /// values.
  DelegateObservableData({D Function() getData, Stream<D> Function() createStream}) {
    _lazySubject = Lazy(() {
      var subject = getData != null ? BehaviorSubject<D>.seeded(getData()) : BehaviorSubject<D>();
      if (createStream != null) {
        subject.addStream(createStream());
      }
      return subject;
    });
  }

  /// Constructs a [DelegateObservableData] that contains a single value that never changes.
  factory DelegateObservableData.single(D data) => DelegateObservableData(getData: () => data);

  @override
  ValueStream<D> get dataStream => _lazySubject.value;
}
