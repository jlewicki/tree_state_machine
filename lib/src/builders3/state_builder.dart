part of tree_builders3;

/// Indicates that a value of type [P] must be provided when entering a state.
///
/// Channels are intended as a contract indicating that in order to transition to a particular
/// state, additional contextual information of type [P] must be provided by the transition source.
/// ```dart
/// class SubmitCredentials {}
/// class AuthenticatedUser {}
/// class AuthFuture {
///   final FutureOr<AuthenticatedUser?> futureOr;
///   AuthFuture(this.futureOr);
/// }
///
/// var loginState = StateKey('login');
/// var authenticatingState = StateKey('authenticating');
///
/// var authenticatingChannel = Channel<SubmitCredentials>(authenticatingState);
///
/// AuthFuture _login(SubmitCredentials creds) {
///   // ...Perform authentication
///   return AuthFuture(Future.value(AuthenticatedUser()));
/// }
/// var treeBuilder = StateTreeBuilder(initialState: loginState);
///
/// treeBuilder.state(loginState, (b) {
///   b.onMessage<SubmitCredentials>((b) {
///     // Provide a SubmitCredentials value when entering authenticating state
///     b.enterChannel(authenticatingChannel, (ctx) => ctx.message);
///   });
/// });
///
/// treeBuilder.state(authenticatingState, (b) {
///   b.onEnterFromChannel<SubmitCredentials>(authenticatingChannel, (b) {
///     // The context argument provides access to the SubmitCredentials value
///     b.post<AuthFuture>(getMessage: (ctx) => _login(ctx.context));
///   });
/// });
class Channel<P> {
  /// The state to enter for this channel.
  final StateKey to;

  /// A descriptive label for this channel.
  final String? label;

  /// Constructs a channel for the [to] state.
  Channel(this.to, {this.label});
}

enum _StateType { root, interior, leaf }

abstract class _StateBuilder {
  final StateKey key;
  final bool _isFinal;
  final List<StateKey> _children = [];
  final Logger _log;
  final InitialChild? _initialChild;
  final Type? _dataType;
  final StateDataCodec? _codec;
  StateKey? _parent;

  // Key is either a Type object representing message type or a message value
  final Map<Object, MessageHandlerDescriptor<void>> _messageHandlerMap = {};
  // 'Open-coded' message handler. This is mutually exclusive with _messageHandlerMap
  MessageHandler? _messageHandler;
  // Builder for onExit handler. This is mutually exclusive with _onExitHandler
  TransitionHandlerDescriptor<void>? _onExit;
  // 'Open-coded' onExit handler. This is mutually exclusive with _onExit
  TransitionHandler? _onExitHandler;
  // Builder for onEnter handler. This is mutually exclusive with _onEnterHandler
  TransitionHandlerDescriptor<void>? _onEnter;
  // 'Open-coded' onEnter handler. This is mutually exclusive with _onEnter
  TransitionHandler? _onEnterHandler;

  _StateBuilder._(
    this.key,
    this._isFinal,
    this._dataType,
    this._codec,
    this._log,
    this._parent,
    this._initialChild,
  );

  _StateType get _stateType {
    if (_parent == null) return _StateType.root;
    if (_children.isEmpty) return _StateType.leaf;
    return _StateType.interior;
  }

  bool get _hasStateData => _dataType != null;

  void _addChild(_StateBuilder child) {
    child._parent = key;
    _children.add(child.key);
  }

  TreeNode _toNode(TreeBuildContext context, Map<StateKey, _StateBuilder> builderMap) {
    switch (_nodeType()) {
      case NodeType.rootNode:
        var childAndLeafBuilders = _children.map((e) => builderMap[e]!);
        return context.buildRoot(
          key,
          (_) => _createState(),
          childAndLeafBuilders.map((cb) {
            return (childCtx) => cb._toNode(childCtx, builderMap);
          }),
          _initialChild!.call,
          _codec,
        );
      case NodeType.interiorNode:
        return context.buildInterior(
          key,
          (_) => _createState(),
          _children.map((e) {
            return (childCtx) => builderMap[e]!._toNode(childCtx, builderMap);
          }),
          _initialChild!.call,
          _codec,
        );
      case NodeType.leafNode:
        return context.buildLeaf(key, (_) => _createState(), _codec);
      case NodeType.finalLeafNode:
        return context.buildLeaf(key, (_) => _createState(), _codec, isFinal: true);
      default:
        throw StateError('Unrecognized node type');
    }
  }

  NodeType _nodeType() {
    if (_parent == null) {
      return NodeType.rootNode;
    } else if (_children.isEmpty) {
      return _isFinal ? NodeType.finalLeafNode : NodeType.leafNode;
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
    if (_messageHandler != null) {
      return _messageHandler!;
    }

    final handlerMap = HashMap.fromEntries(
      _messageHandlerMap.entries.map((e) => MapEntry(e.key, e.value.makeHandler())),
    );

    return (MessageContext msgCtx) {
      var msg = msgCtx.message;
      // Note that if message handlers were registered by message type, then the runtime type of
      // a message must exactly match the registered type. That is, a message cannot be a subclass
      // of the registered type. Can we do better?
      var handler = handlerMap[msg] ?? handlerMap[msg.runtimeType];
      return handler != null ? handler(msgCtx) : msgCtx.unhandled();
    };
  }

  TransitionHandler _createOnEnter() {
    final onEnterHandler = _onEnterHandler;
    final onEnterDescriptor = _onEnter;
    if (onEnterHandler != null) {
      return onEnterHandler;
    } else if (onEnterDescriptor != null) {
      return onEnterDescriptor.makeHandler();
    }
    return emptyTransitionHandler;
  }

  TransitionHandler _createOnExit() {
    final onExitHandler = _onExitHandler;
    final onExitDescriptor = _onExit;
    if (onExitHandler != null) {
      return onExitHandler;
    } else if (onExitDescriptor != null) {
      return onExitDescriptor.makeHandler();
    }
    return emptyTransitionHandler;
  }

  void _makeVoidTransitionContext(TransitionContext ctx) {}
  void _makeVoidMessageContext(MessageContext ctx) {}
}

/// Provides methods for describing the behavior of a state, carrying state data of type [D], when
/// is entered. [D] may be `void` if the state does not have any associated state data.
abstract class EnterStateBuilder<D> {
  /// Describes how transitions to this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the entry transition.
  void onEnter(void Function(TransitionHandlerBuilder<D, void>) build);

  /// Describes how transitions to this state should be handled.
  ///
  /// This method can be used when the entry handler requires access to state data of type [D2] from
  /// an ancestor state.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to
  /// describe the behavior of the exit transition.
  void onEnterWithData<D2>(void Function(TransitionHandlerBuilder<D, D2>) build);

  /// Describes how transition to this state through [channel] should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used
  /// to describe the behavior of the entry transition.
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilder<D, P>) build,
  );
}

/// Provides methods for describing the behavior of a state carrying state data of type [D]. [D] may
/// be `void` if the state does not have any associated state data.
class StateBuilder<D> extends _StateBuilder implements EnterStateBuilder<D> {
  final InitialData<D> _typedInitialData;

  StateBuilder._(
    StateKey key,
    this._typedInitialData,
    Logger log,
    StateKey? parent,
    InitialChild? initialChild, {
    required bool isFinal,
    StateDataCodec? codec,
  }) : super._(
          key,
          isFinal,
          _isEmptyDataType<D>() ? null : D,
          codec,
          log,
          parent,
          initialChild,
        );

  @override
  void onEnter(
    void Function(TransitionHandlerBuilder<D, void>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, void>._(key, _log, _makeVoidTransitionContext);
    build(builder);
    _onEnter = builder._descriptor;
  }

  @override
  void onEnterWithData<D2>(
    void Function(TransitionHandlerBuilder<D, D2>) build,
  ) {
    var builder =
        TransitionHandlerBuilder<D, D2>._(key, _log, (transCtx) => transCtx.dataValueOrThrow<D2>());
    build(builder);
    _onEnter = builder._descriptor;
  }

  @override
  void onEnterFromChannel<P>(
    Channel<P> channel,
    void Function(TransitionHandlerBuilder<D, P>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, P>._(
      key,
      _log,
      (transCtx) => transCtx.payloadOrThrow<P>(),
    );
    build(builder);
    _onEnter = builder._descriptor;
  }

  /// Describes how messages of type [M] should be handled by this state.
  ///
  /// The [build] function is called with a [MessageHandlerBuilder] that can be used to describe
  /// the behavior of the message handler.
  void onMessage<M>(void Function(MessageHandlerBuilder<M, D, void> b) build) {
    var builder = MessageHandlerBuilder<M, D, void>(key, _makeVoidMessageContext, _log, null);
    build(builder);
    if (builder.descriptor != null) {
      _messageHandlerMap[M] = builder.descriptor!;
    }
  }

  /// Describes how a message value of type [M] should be handled by this state.
  ///
  /// The [build] function is called with a [MessageHandlerBuilder] that can be used to describe
  /// the behavior of the message handler.
  void onMessageValue<M>(
    M message,
    void Function(MessageHandlerBuilder<M, D, void> b) build, {
    String? messageName,
  }) {
    var builder = MessageHandlerBuilder<M, D, void>(key, _makeVoidMessageContext, _log, null);
    build(builder);
    if (builder.descriptor != null) {
      _messageHandlerMap[message as Object] = builder.descriptor!;
    }
  }

  /// Describes how transitions from this state should be handled.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to describe
  /// the behavior of the exit transition.
  void onExit(
    void Function(TransitionHandlerBuilder<D, void>) build,
  ) {
    var builder = TransitionHandlerBuilder<D, void>._(key, _log, _makeVoidTransitionContext);
    build(builder);
    _onExit = builder._descriptor;
  }

  /// Describes how transitions from this state should be handled.
  ///
  /// This method can be used when the exit handler requires access to state data of type [D2] from
  /// an ancestor state.
  ///
  /// The [build] function is called with a [TransitionHandlerBuilder] that can be used to
  /// describe the behavior of the exit transition.
  void onExitWithData<D2>(
    void Function(TransitionHandlerBuilder<D, D2>) build,
  ) {
    var builder =
        TransitionHandlerBuilder<D, D2>._(key, _log, (transCtx) => transCtx.dataValueOrThrow<D2>());
    build(builder);
    _onExit = builder._descriptor;
  }

  @override
  TreeState _createState() {
    return _hasStateData
        ? DelegatingDataTreeState<D>(
            _typedInitialData.call,
            _createMessageHandler(),
            _createOnEnter(),
            _createOnExit(),
            () {},
          )
        : super._createState();
  }

  static bool _isEmptyDataType<D>() => !isTypeOf<D, void>();
}

/// Provides methods for describing the transition from a [StateTreeBuilder.machineState] that
/// occurs when the nested state machine completes.
class MachineStateBuilder extends _StateBuilder {
  final InitialMachine _initialMachine;
  final bool Function(Transition transition)? _isDone;
  final _currentStateRef = Ref<CurrentState?>(null);
  MessageHandlerDescriptor<CurrentState>? _doneDescriptor;
  MessageHandlerDescriptor<void>? _disposedDescriptor;

  MachineStateBuilder(
    StateKey key,
    this._initialMachine,
    this._isDone,
    Logger log,
    StateKey? parent, {
    required bool isFinal,
    StateDataCodec? codec,
  }) : super._(key, isFinal, NestedMachineData, codec, log, parent, null);

  void onMachineDone(
      void Function(MachineDoneHandlerBuilder<void, CurrentState> builder) buildHandler) {
    var builder = MachineDoneHandlerBuilder<void, CurrentState>(
      key,
      (_) => _currentStateRef.value!,
      _log,
      null,
    );
    buildHandler(builder);
    _doneDescriptor = builder.descriptor;
  }

  @override
  TreeState _createState() {
    var doneDescriptor = _doneDescriptor;
    if (doneDescriptor == null) {
      throw StateError(
          "Nested machine state '$key' does not have a done handler. Make sure to call onMachineDone.");
    }

    return NestedMachineState(
      _initialMachine,
      (currentState) {
        _currentStateRef.value = currentState;
        return doneDescriptor.makeHandler();
      },
      _log,
      _isDone,
      _disposedDescriptor?.makeHandler(),
    );
  }
}
