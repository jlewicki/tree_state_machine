part of fluent_tree_builders;

/// Provides methods for describing the behavior of a state in a state tree.
class StateBuilder {
  final StateKey key;
  final bool isFinal;
  // Key is either a Type object representing message type or a message value
  final Map<Object, List<_MessageHandlerInfo>> _messageHandlerMap = {};
  final List<StateKey> _children = [];
  List<_TransitionHandlerInfo> _onEnters = [];
  List<_TransitionHandlerInfo> _onExits = [];
  StateKey _parent;
  StateKey _initialChild;

  StateBuilder._(this.key, {this.isFinal = false});

  /// Indicates that [parent] is the parent state of this state.
  ///
  /// If this method is not called, this builder will build a root state.
  StateBuilder withParent(StateKey parent) {
    _parent = parent;
    return this;
  }

  /// Indicates that the [initialChild] state should be entered, when this state is entered.
  ///
  /// Calling this method means that this builder will build a an interior (that is, a non-leaf)
  /// state.
  StateBuilder withInitialChild(StateKey initialChild) {
    if (initialChild == this.key) {
      throw ArgumentError('Initial child cannot be state state as parent ${key}');
    }
    _initialChild = initialChild;
    return this;
  }

  /// Describes how transitions to this state should be handled.
  ///
  /// The [handler] function is called with a [EntryTransitionHandlerBuilder] that can be used to
  /// describe how the tranisition is handled.
  StateBuilder onEnter<D, P>(
    void Function(EntryTransitionHandlerBuilder<D, P>) handler,
  ) {
    var builder = EntryTransitionHandlerBuilder<D, P>._(this.key);
    handler(builder);
    _onEnters.addAll(builder._handlers);
    return this;
  }

  /// Describes how transitions from this state should be handled.
  ///
  /// The [handler] function is called with a [TransitionHandlerBuilder] that can be used to
  /// describe how the tranisition is handled.
  StateBuilder onExit<D>(
    void Function(TransitionHandlerBuilder<D>) handler,
  ) {
    if (isFinal) {
      throw ArgumentError('Exit handlers cannot be registered for final states.');
    }
    var builder = TransitionHandlerBuilder<D>(this.key);
    handler(builder);
    _onExits.addAll(builder._handlers);
    return this;
  }

  /// Describes how messages of type [M] should be handled by this state.
  ///
  /// The [handler] function is called with a [MessageHandlerBuilder] that can be used to describe
  /// how the message is handled.
  ///
  /// If [message] is provided, then the handler will be invoked when an equivalent message is
  /// received by the state.  Otherwise, the handler will be invoked when a message of type [M] is
  /// received.
  StateBuilder onMessage<M>(
    void Function(MessageHandlerBuilder<M> b) handler, {
    M message,
  }) {
    if (isFinal) {
      throw ArgumentError('Message handlers cannot be registered for final states.');
    }

    var messageType = TypeLiteral<M>().type;
    var messageKey = message ?? messageType;
    var registeredHandlers = _messageHandlerMap[messageKey] ?? [];
    var builder = MessageHandlerBuilder<M>(this.key);
    handler(builder);
    registeredHandlers.addAll(builder._handlers);
    _messageHandlerMap[messageKey] = registeredHandlers;
    return this;
  }

  TransitionHandler _buildTransitionHandler(List<_TransitionHandlerInfo> handlers) {
    // Helper to iterate through guarded handlers until a guard allows the handler
    // to run.
    FutureOr<void> _runGuardedHandlers(
      Iterator<_TransitionHandlerInfo> handlerIterator,
      TransitionContext transitionContext,
    ) {
      if (handlerIterator.moveNext()) {
        final handler = handlerIterator.current;
        final guard = handler.guard ?? (transCtx) => true;
        final guardResult = guard(transitionContext);
        final afterGuard = (bool allowed) {
          return allowed
              ? handler.transitionHandler(transitionContext)
              : _runGuardedHandlers(handlerIterator, transitionContext);
        };
        return guardResult is Future<bool>
            ? guardResult.then(afterGuard)
            : afterGuard(guardResult as bool);
      }
    }

    return (ctx) {
      var result = _runGuardedHandlers(handlers.iterator, ctx);
      return result;
    };
  }

  _StateType get _stateType {
    if (_parent == null) return _StateType.root;
    if (_children.isEmpty) return _StateType.leaf;
    return _StateType.interior;
  }

  MessageHandler _buildMessageHandler() {
    // Helper to iterate through guarded handlers until a guard allows the handler
    // to run.
    FutureOr<MessageResult> _runGuardedHandlers(
      Iterator<_MessageHandlerInfo> handlerIterator,
      MessageContext messageContext,
    ) {
      if (handlerIterator.moveNext()) {
        final handler = handlerIterator.current;
        final guard = handler.guard ?? (msgCtx) => true;
        final result = guard(messageContext);
        final afterGuard = (bool allowed) {
          var handlerResult = allowed
              ? handler.messageHandler(messageContext)
              : _runGuardedHandlers(handlerIterator, messageContext);
          return handlerResult;
        };
        return result is Future<bool> ? result.then(afterGuard) : afterGuard(result as bool);
      }
      return messageContext.unhandled();
    }

    return (msgCtx) {
      var guardedHandlers = _messageHandlerMap[msgCtx.message] ??
          _messageHandlerMap[msgCtx.message.runtimeType] ??
          [];
      var result = _runGuardedHandlers(guardedHandlers.iterator, msgCtx);
      return result;
    };
  }

  static NodeBuilder<ChildNode> _createChildNodeBuilder(
    StateBuilder b,
    Map<StateKey, StateBuilder> stateBuilders,
  ) {
    switch (b._stateType) {
      case _StateType.interior:
        return b._toInteriorNode(stateBuilders);
      case _StateType.leaf:
        return b._toLeafNode();
      default:
        throw StateError('${b.key} is not a child node');
    }
  }

  NodeBuilder<RootNode> _toRootNode(
    Map<StateKey, StateBuilder> stateBuilders,
    Iterable<StateBuilder> finalBuilders,
  ) {
    assert(_stateType == _StateType.root);
    assert(_initialChild != null);
    return Root<DelegateState>(
      key: key,
      initialChild: (_) => _initialChild,
      createState: (_) => _toTreeState(),
      children: _children
          .map((c) => stateBuilders[c])
          .where((b) => !finalBuilders.contains(b))
          .map((b) => _createChildNodeBuilder(b, stateBuilders)),
      finals: finalBuilders.map((b) => b._toFinalNode()),
    );
  }

  NodeBuilder<LeafNode> _toLeafNode() {
    assert(_stateType == _StateType.leaf);
    return Leaf<DelegateState>(key: key, createState: (_) => _toTreeState());
  }

  NodeBuilder<FinalNode> _toFinalNode() {
    assert(_stateType == _StateType.leaf);
    return Final<DelegateFinalState>(key: key, createState: (_) => _toTreeState());
  }

  NodeBuilder<InteriorNode> _toInteriorNode(
    Map<StateKey, StateBuilder> stateBuilders,
  ) {
    assert(_stateType == _StateType.interior);
    assert(_initialChild != null);
    return Interior<DelegateState>(
      key: key,
      initialChild: (_) => _initialChild,
      createState: (_) => _toTreeState(),
      children: _children
          .map((c) => stateBuilders[c])
          .map((b) => _createChildNodeBuilder(b, stateBuilders)),
    );
  }

  TreeState _toTreeState() {
    return this.isFinal
        ? DelegateFinalState(_buildTransitionHandler(_onEnters))
        : DelegateState(
            messageHandler: _buildMessageHandler(),
            entryHandler: _buildTransitionHandler(_onEnters),
            exitHandler: _buildTransitionHandler(_onExits),
          );
  }
}

/// Provides methods for describing the behavior of a data state, with state data of type [D].
class DataStateBuilder<D> extends StateBuilder {
  DataProvider<D> Function() _createProvider;

  DataStateBuilder._(StateKey key) : super._(key);

  /// Indicates the [createProvider] function should be used to create the [DataProvider] for this
  /// state.
  DataStateBuilder<D> withDataProvider(DataProvider<D> Function() createProvider) {
    _createProvider = createProvider;
    return this;
  }

  @override
  TreeState _toTreeState() {
    return isFinal
        ? DelegateFinalState(_buildTransitionHandler(_onEnters))
        : DelegateDataState<D>(
            messageHandler: _buildMessageHandler(),
            entryHandler: _buildTransitionHandler(_onEnters),
            exitHandler: _buildTransitionHandler(_onExits),
          );
  }

  @override
  NodeBuilder<RootNode> _toRootNode(
    Map<StateKey, StateBuilder> stateBuilders,
    Iterable<StateBuilder> finalBuilders,
  ) {
    return RootWithData<DelegateDataState<D>, D>(
      key: key,
      initialChild: (_) => _initialChild,
      createState: (_) => _toTreeState(),
      createProvider: _createProvider,
      children: _children
          .map((c) => stateBuilders[c])
          .map((b) => StateBuilder._createChildNodeBuilder(b, stateBuilders)),
      finals: finalBuilders.map((b) => StateBuilder._createChildNodeBuilder(b, stateBuilders)),
    );
  }

  @override
  NodeBuilder<LeafNode> _toLeafNode() {
    return LeafWithData<DelegateDataState<D>, D>(
      key: key,
      createState: (_) => _toTreeState(),
      createProvider: _createProvider,
    );
  }

  @override
  NodeBuilder<InteriorNode> _toInteriorNode(
    Map<StateKey, StateBuilder> stateBuilders,
  ) {
    return InteriorWithData<DelegateDataState<D>, D>(
      key: key,
      createState: (_) => _toTreeState(),
      createProvider: _createProvider,
      initialChild: (_) => _initialChild,
      children: _children
          .map((c) => stateBuilders[c])
          .map((b) => StateBuilder._createChildNodeBuilder(b, stateBuilders)),
    );
  }

  Type get dataType => TypeLiteral<D>().type;
}

class FinalStateBuilder {
  final StateBuilder _stateBuilder;
  FinalStateBuilder._(StateKey key) : this._stateBuilder = StateBuilder._(key, isFinal: true);

  FinalStateBuilder onEnter<D, P>(
    void Function(EntryTransitionHandlerBuilder<D, P>) handler,
  ) {
    _stateBuilder.onEnter<D, P>(handler);
    return this;
  }
}
