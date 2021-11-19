part of tree_builders;

enum _StateType { root, interior, leaf }

abstract class _OnEntryBuilder implements _OpaqueOnEntryBuilder {
  /// Describes how transitions to this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the entry transition.
  void onEnter(void Function(TransitionHandlerBuilder b) build);

  /// Describes how transitions to this state should be handled.
  ///
  /// This method can be used when the entry handler requires access to state data of an ancestor
  /// state.
  ///
  /// ```dart
  ///  // Root state carrying BugData instance
  ///  var b = StateTreeBuilder.withDataRoot<BugData>(
  ///    States.root,
  ///    InitialData.value(BugData()..title = 'New Bug'),
  ///    emptyDataState,
  ///    InitialChild.key(States.open),
  ///  );
  ///
  ///  b.state(States.deferred, (b) {
  ///    // When  deferred state is entered, update the BugData insance of the parent state
  ///    b.onEnterWithData<BugData>((b) => b.updateData(
  ///      (_, data) => data..assignee = null,
  ///      label: 'clear assignee',
  ///    ));
  ///  }, parent: States.root);
  /// ```
  ///
  /// The [build] function is called with a [TransitionHandlerBuilderWithData] that can be used to
  /// describe the behavior of the entry transition.
  void onEnterWithData<D>(void Function(TransitionHandlerBuilderWithData<D>) build);

  /// Describes how transition to this state through [channel] should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilderWithPayload] that can be used
  /// to describe the behavior of the entry transition.
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilderWithPayload<P>) build,
  );
}

abstract class _OnEntryWithDataBuilder<D> implements _OpaqueOnEntryBuilder {
  /// Describes how transitions to this data state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilderWithData] that can be used to
  /// describe
  /// the behavior of the entry transition.
  void onEnter(void Function(TransitionHandlerBuilderWithData<D> b) build);

  /// Describes how transition to this state through [channel] should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilderWithDataAndPayload] that can be used
  /// to describe the behavior of the entry transition.
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilderWithDataAndPayload<D, P>) build,
  );
}

abstract class _OpaqueOnMessageBuilder {
  /// Registers [handler] as the message handler function for this state.
  ///
  /// This method supports adding 'open-coded' handlers to the state. Because the handler function
  /// was not described calling builder methods, the specific behavior of the method will be opaque
  /// to a [StateTreeFormatter] when [StateTreeBuilder.format] is called. As a result, the graph
  /// description produced by the formatter may not be particularly useful. This method is best
  /// avoided if the formatting feature is important to you.
  void runOnMessage(MessageHandler handler);
}

abstract class _OpaqueOnEntryBuilder {
  /// Registers [handler] as the onEnter handler function for this state.
  ///
  /// This method supports adding 'open-coded' handlers to the state. Because the handler function
  /// was not described calling builder methods, the specific behavior of the method will be opaque
  /// to a [StateTreeFormatter] when [StateTreeBuilder.format] is called. As a result, the graph
  /// description produced by the formatter may not be particularly useful. This method is best
  /// avoided if the formatting feature is important to you.
  void runOnEnter(TransitionHandler handler);
}

abstract class _OpaqueOnExitBuilder {
  /// Registers [handler] as the onExit handler function for this state.
  ///
  /// This method supports adding 'open-coded' handlers to the state. Because the handler function
  /// was not described calling builder methods, the specific behavior of the method will be opaque
  /// to a [StateTreeFormatter] when [StateTreeBuilder.format] is called. As a result, the graph
  /// description produced by the formatter may not be particularly useful. This method is best
  /// avoided if the formatting feature is important to you.
  void runOnExit(TransitionHandler handler);
}

/// Provides methods for describing the behavior of a state.
abstract class StateBuilder
    implements _OnEntryBuilder, _OpaqueOnExitBuilder, _OpaqueOnMessageBuilder {
  ///
  void onMessage<M>(void Function(MessageHandlerBuilder<M> b) buildHandler);

  ///
  void onMessageValue<M>(
    M message,
    void Function(MessageHandlerBuilder<M> b) buildHandler, {
    String? messageName,
  });

  /// Describes how transitions from this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the exit transition.
  void onExit(void Function(TransitionHandlerBuilder b) buildHandler);

  /// Describes how transitions from this state should be handled.
  ///
  /// This method can be used when the exit handler requires access to state data of an ancestor
  /// state.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilderWithData] that can be used to
  /// describe the behavior of the exit transition.
  void onExitWithData<D>(void Function(TransitionHandlerBuilderWithData<D>) handler);
}

/// Provides methods for describing the behavior of a final state in a state tree.
///
/// A final state is a terminal state for a state tree. Once a final state has beem entered, no
/// further messsage processing or state transitions will occur. As a result, only state entry
/// behavior may be defined for a final state with this builder.
abstract class FinalStateBuilder implements _OnEntryBuilder {}

/// Provides methods for describing the behavior of a data state carrying a value of type [D].
abstract class DataStateBuilder<D>
    implements
        _OpaqueOnEntryBuilder,
        _OpaqueOnExitBuilder,
        _OpaqueOnMessageBuilder,
        _OnEntryWithDataBuilder<D> {
  void onMessage<M>(void Function(DataMessageHandlerBuilder<M, D> b) handler);

  void onMessageValue<M>(
    M message,
    void Function(DataMessageHandlerBuilder<M, D> b) handler, {
    String? messageName,
  });

  void onExit(void Function(TransitionHandlerBuilderWithData<D>) handler);
}

/// Provides methods for describing the behavior of a final data state carrying a value of type [D].
///
/// A final state is a terminal state for a state tree. Once a final state has beem entered, no
/// further messsage processing or state transitions will occur. As a result, only state entry
/// behavior may be defined for a final state with this builder.
abstract class FinalDataStateBuilder<D> implements _OnEntryWithDataBuilder<D> {}

/// Base class for state builders that allow the behavior of a state to be specified.
abstract class _StateBuilderBase {
  final StateKey key;
  final bool isFinal;
  final List<StateKey> _children = [];
  final InitialChild? _initialChild;
  final Logger _log;
  StateKey? _parent;
  // Key is either a Type object representing message type or a message value
  final Map<Object, _MessageHandlerInfo> _messageHandlerMap = {};
  // 'Open-coded' message handler. This is mutually exclusive with _messageHandlerMap
  MessageHandler? _messageHandler;
  // Builder for onExit handler. This is mutually exclusive with _onExitHandler
  _TransitionHandlerDescriptor? _onExit;
  // 'Open-coded' onExit handler. This is mutually exclusive with _onExit
  TransitionHandler? _onExitHandler;
  // Builder for onEnter handler. This is mutually exclusive with _onEnterHandler
  _TransitionHandlerDescriptor? _onEnter;
  // 'Open-coded' onEnter handler. This is mutually exclusive with _onEnter
  TransitionHandler? _onEnterHandler;

  _StateBuilderBase._(this.key, this.isFinal, this._log, this._parent, this._initialChild);

  _StateType get _stateType {
    if (_parent == null) return _StateType.root;
    if (_children.isEmpty) return _StateType.leaf;
    return _StateType.interior;
  }

  StateDataCodec? get serializer => null;

  void _addChild(_StateBuilderBase child) {
    child._parent = key;
    _children.add(child.key);
  }

  TreeNode _toNode(TreeBuildContext context, Map<StateKey, _StateBuilderBase> builderMap) {
    switch (_nodeType()) {
      case NodeType.rootNode:
        var childAndLeafBuilders = _children.map((e) => builderMap[e]!);
        return context._buildRoot(
          key,
          (_) => _createState(),
          childAndLeafBuilders.map((cb) {
            return (childCtx) => cb._toNode(childCtx, builderMap);
          }),
          _initialChild!.eval,
          serializer,
        );
      case NodeType.interiorNode:
        return context._buildInterior(
          key,
          (_) => _createState(),
          _children.map((e) {
            return (childCtx) => builderMap[e]!._toNode(childCtx, builderMap);
          }),
          _initialChild!.eval,
          serializer,
        );
      case NodeType.leafNode:
        return context._buildLeaf(key, (_) => _createState(), serializer);
      case NodeType.finalLeafNode:
        return context._buildLeaf(key, (_) => _createState(), serializer, isFinal: true);
      default:
        throw StateError('Unrecognized node type');
    }
  }

  NodeType _nodeType() {
    if (_parent == null) {
      return NodeType.rootNode;
    } else if (_children.isEmpty) {
      return isFinal ? NodeType.finalLeafNode : NodeType.leafNode;
    }
    return NodeType.interiorNode;
  }

  TreeState _createState() {
    return DelegatingTreeState(
      _createMessageHandler(),
      _createOnEnter(),
      _createOnExit(),
      null,
    );
  }

  MessageHandler _createMessageHandler() {
    final messageHandler = _messageHandler;
    final handlerMap = {..._messageHandlerMap};
    return (MessageContext msgCtx) {
      if (messageHandler != null) {
        return messageHandler(msgCtx);
      }
      var msg = msgCtx.message;
      // Note thay if message handlers were registered by message type, that means runtime type of
      // a message must exactly match the registered type. That is, a message cannot be a subclass
      // of the registered type.
      var descriptor = handlerMap[msg] ?? handlerMap[msg.runtimeType];
      return descriptor is _MessageHandlerDescriptor
          ? descriptor.handler(msgCtx)
          : msgCtx.unhandled();
    };
  }

  TransitionHandler _createOnEnter() {
    final onEnterHandler = _onEnterHandler;
    final onEnterDescriptor = _onEnter;
    return (TransitionContext transCtx) {
      if (onEnterHandler != null) {
        return onEnterHandler(transCtx);
      } else if (onEnterDescriptor != null) {
        return onEnterDescriptor._handler(transCtx);
      }
    };
  }

  TransitionHandler _createOnExit() {
    final onExitHandler = _onExitHandler;
    final onExitDescriptor = _onExit;
    return (TransitionContext transCtx) {
      if (onExitHandler != null) {
        return onExitHandler(transCtx);
      } else if (onExitDescriptor != null) {
        return onExitDescriptor._handler(transCtx);
      }
    };
  }
}

/// Provides methods for describing the behavior of a state in a state tree
class _StateBuilder extends _StateBuilderBase
    with _OpaqueHandlersMixin
    implements StateBuilder, FinalStateBuilder {
  _StateBuilder._(StateKey key, Logger log, StateKey? parent, InitialChild? initialChild,
      [bool isFinal = false])
      : super._(key, isFinal, log, parent, initialChild);

  @override
  void onEnter(void Function(TransitionHandlerBuilder b) build) {
    var builder = TransitionHandlerBuilder._(key);
    build(builder);
    _onEnter = builder._handler;
  }

  @override
  void onEnterWithData<D>(void Function(TransitionHandlerBuilderWithData<D>) handler) {
    var builder = TransitionHandlerBuilderWithData<D>._(key);
    handler(builder);
    _onEnter = builder._handler;
  }

  @override
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilderWithPayload<P>) handler,
  ) {
    var builder = TransitionHandlerBuilderWithPayload<P>._();
    handler(builder);
    _onEnter = builder._handler;
  }

  @override
  void onMessage<M>(void Function(MessageHandlerBuilder<M> b) buildHandler) {
    if (isFinal) {
      throw ArgumentError('Message handlers cannot be registered for final states.');
    }

    var builder = MessageHandlerBuilder<M>._(key, _log, null);
    buildHandler(builder);
    if (builder._handler != null) {
      var messageKey = TypeLiteral<M>().type;
      _messageHandlerMap[messageKey] = builder._handler!;
    }
  }

  @override
  void onMessageValue<M>(
    M message,
    void Function(MessageHandlerBuilder<M> b) buildHandler, {
    String? messageName,
  }) {
    if (isFinal) {
      throw ArgumentError('Message handlers cannot be registered for final states.');
    }

    var messageType = TypeLiteral<M>().type;
    messageName = _getMessageName(messageName, message);
    var builder = MessageHandlerBuilder<M>._(key, _log, messageName);
    buildHandler(builder);
    if (builder._handler != null) {
      var messageKey = message ?? messageType;
      _messageHandlerMap[messageKey] = builder._handler!;
    }
  }

  @override
  void onExit(void Function(TransitionHandlerBuilder b) buildHandler) {
    var builder = TransitionHandlerBuilder._(key);
    buildHandler(builder);
    _onExit = builder._handler;
  }

  @override
  void onExitWithData<D>(void Function(TransitionHandlerBuilderWithData<D>) handler) {
    var builder = TransitionHandlerBuilderWithData<D>._(key);
    handler(builder);
    _onExit = builder._handler;
  }
}

class _DataStateBuilder<D> extends _StateBuilderBase
    with _OpaqueHandlersMixin
    implements DataStateBuilder<D>, FinalDataStateBuilder<D> {
  final Type dataType = D;
  final InitialData<D> _initialValue;
  @override
  final StateDataCodec? serializer;

  _DataStateBuilder._(
    StateKey key,
    this._initialValue,
    Logger log,
    this.serializer,
    StateKey? parent,
    InitialChild? initialChild,
    bool isFinal,
  ) : super._(key, isFinal, log, parent, initialChild);

  @override
  void onEnter(void Function(TransitionHandlerBuilderWithData<D>) handler) {
    var builder = TransitionHandlerBuilderWithData<D>._(key);
    handler(builder);
    _onEnter = builder._handler;
  }

  @override
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilderWithDataAndPayload<D, P>) handler,
  ) {
    var builder = TransitionHandlerBuilderWithDataAndPayload<D, P>._();
    handler(builder);
    _onEnter = builder._handler;
  }

  @override
  void onMessage<M>(void Function(DataMessageHandlerBuilder<M, D> b) handler) {
    if (isFinal) {
      throw ArgumentError('Message handlers cannot be registered for final states.');
    }
    var messageKey = TypeLiteral<M>().type;
    var builder = DataMessageHandlerBuilder<M, D>(key, null, _log);
    handler(builder);
    _messageHandlerMap[messageKey] = builder._handler!;
  }

  @override
  void onMessageValue<M>(
    M message,
    void Function(DataMessageHandlerBuilder<M, D> b) handler, {
    String? messageName,
  }) {
    if (isFinal) {
      throw ArgumentError('Message handlers cannot be registered for final states.');
    }

    var messageType = TypeLiteral<M>().type;
    var messageKey = message ?? messageType;
    var builder = DataMessageHandlerBuilder<M, D>(key, _getMessageName(messageName, message), _log);
    handler(builder);
    _messageHandlerMap[messageKey] = builder._handler!;
  }

  @override
  void onExit(void Function(TransitionHandlerBuilderWithData<D>) handler) {
    var builder = TransitionHandlerBuilderWithData<D>._(key);
    handler(builder);
    _onExit = builder._handler;
  }

  @override
  TreeState _createState() {
    return DelegatingDataTreeState<D>(
      _initialValue,
      _createMessageHandler(),
      _createOnEnter(),
      _createOnExit(),
      emptyDispose,
    );
  }
}

abstract class MachineStateBuilder {
  void onMachineDone(void Function(MachineDoneHandlerBuilder builder) buildHandler);
  void onMachineDisposed(void Function(MachineDisposedHandlerBuilder builder) buildHandler);
}

class _MachineStateBuilder extends _StateBuilderBase implements MachineStateBuilder {
  final InitialMachine _initialMachine;
  final bool Function(Transition transition)? _isDone;
  _ContinuationMessageHandlerDescriptor<CurrentState>? _doneHandler;
  _MessageHandlerDescriptor? _disposedHandler;

  _MachineStateBuilder(
    StateKey key,
    this._initialMachine,
    this._isDone,
    Logger log,
    StateKey? parent,
  ) : super._(key, false, log, parent, null);

  @override
  void onMachineDone(void Function(MachineDoneHandlerBuilder builder) buildHandler) {
    var messageName = _getMessageName('Machine Done');
    var builder = MachineDoneHandlerBuilder._(key, _log, messageName);
    buildHandler(builder);
    _doneHandler = builder._handler;
    _messageHandlerMap[messageName] = _doneHandler!;
  }

  @override
  void onMachineDisposed(void Function(MachineDisposedHandlerBuilder builder) buildHandler) {
    var messageName = _getMessageName('Machine Disposed');
    var builder = MachineDisposedHandlerBuilder._(key, _log, messageName);
    buildHandler(builder);
    _disposedHandler = builder._handler;
    _messageHandlerMap[messageName] = _disposedHandler!;
  }

  String _getMessageName(String messageName) {
    // Placeholder for future labeling of messages
    return messageName;
  }

  @override
  TreeState _createState() {
    var doneHandler = _doneHandler;
    if (doneHandler == null) {
      throw StateError(
          "Nested machine state '$key' does not have a done handler. Make sure to call onMachineDone.");
    }

    return NestedMachineState(
      _initialMachine,
      doneHandler.continuation,
      _log,
      _isDone,
      _disposedHandler?.handler,
    );
  }
}

/// Adds methods to builders that allows 'open-coded' handlers to be added to builders.
///
/// Note that these methods are added via mixin instead of addinging then to StateBuilderBase,
/// because we don't want FinalStateBuilder to have then
mixin _OpaqueHandlersMixin on _StateBuilderBase {
  void runOnMessage(MessageHandler handler) {
    if (_messageHandlerMap.isNotEmpty) {
      throw StateError('Message handlers have already been added by calling onMessage or '
          'onMessageValue, and would be overwritten by this message handler.');
    }
    _messageHandler = handler;
  }

  void runOnEnter(TransitionHandler handler) {
    if (_onEnter != null) {
      throw StateError('A onEnter handler has already been added by calling onEnter, and would be '
          'overwritten by this transition handler.');
    }
    _onEnterHandler = handler;
  }

  void runOnExit(TransitionHandler handler) {
    if (_onExit != null) {
      throw StateError('A onExit handler has already been added by calling onExit, and would be '
          'overwritten by this transition handler.');
    }
    _onExitHandler = handler;
  }
}

String? _getMessageName(String? messageName, message) {
  messageName = messageName ?? message.toString();
  if (isEnumValue(message as Object)) {
    messageName = describeEnum(message);
  }
  return messageName;
}
