part of '../../tree_builders.dart';

/// Provides methods to describe a state tree.
///
/// States are defined and added to the state tree are described by calling methods such [state],
/// [dataState], and [finalState]. A state tree or state machine can be nested within another state
/// tree with the [machineState] method.
///
/// ```dart
/// enum Messages { toggle }
/// var offState = StateKey('off');
/// var onState = StateKey('on');
///
/// StateTreeBuilder switchBuilder() {
///   // A simple switch with on and off states
///   var treeBuilder = StateTreeBuilder(initialChild: offState)
///   treeBuilder.state(offState, (b) {
///     b.onMessageValue(Messages.toggle, (b) => b.goTo(onState));
///   })
///   treeBuilder.state(onState, (b) {
///     b.onMessageValue(Messages.toggle, (b) => b.goTo(offState));
///   });
///   return treeBuilder;
/// }
/// ```
/// Once a [StateTreeBuilder] has been initialized with the desired states, it can be used to create
/// a state machine. The state machine will create and manage its own instance of the state tree
/// defined by the builder.
///
/// ```dart
///  var stateTreeBuilder = switchBuilder();
///  var stateMachine = TreeStateMachine(builder);
/// ```
///
/// Note that a single state tree builder instance can be used to create multiple state machine
/// instances.
///
/// A textual description of the state tree can be produced by calling [format] method, passing a
/// [StateTreeFormatter] (for example a [DotFormatter]) representing the desired output format.
class StateTreeBuilder {
  final StateKey _rootKey;
  final Map<StateKey, _StateBuilder> _stateBuilders = {};
  late final Logger _log = Logger(
    'tree_state_machine.StateTreeBuilder${logName != null ? '.${logName!}' : ''}',
  );

  StateTreeBuilder._(this._rootKey, this.label, String? logName) : logName = logName ?? label;

  /// The key identifying the root state that is implicitly added to a state tree, if the
  /// [StateTreeBuilder.new] constructor is used.
  static const StateKey defaultRootKey = StateKey('<_RootState_>');

  /// An optional descriptive label for this state tree, for diagnostic purposes.
  final String? label;

  /// An optional name for this state tree that will be used as the suffix of the logger name used
  /// when logging messages.
  ///
  /// This can be used to correlate log messages with specific state trees when examining the log
  /// output.
  final String? logName;

  /// The key indentifying the root state of the state tree.
  StateKey get rootKey => _rootKey;

  /// Creates a [StateTreeBuilder] that will build a state tree that starts in the state identified
  /// by [initialChild].
  ///
  /// The state tree has an implicit root state, identified by [StateTreeBuilder.defaultRootKey].
  /// This state has no associated behavior, and it is typically safe to ignore its presence.
  /// States defined with this builder that do not speciy a parent state in their definition will
  /// be considered children of the implicit root.
  ///
  /// [initialChild] must refer to a state that is a child of the implicit root. Otherwise a
  /// [StateTreeDefinitionError] will be thrown when a [TreeStateMachine] is constructed with this
  /// builder.
  ///
  /// The builder can optionally be given a [label] for diagnostic purposes, and a [logName] which
  /// identifies the builder in log output. If [logName] is unspecifed, [label] will be used instead.
  factory StateTreeBuilder({required StateKey initialChild, String? label, String? logName}) {
    var b = StateTreeBuilder._(defaultRootKey, label, logName);
    b.state(defaultRootKey, emptyState, initialChild: InitialChild(initialChild));
    return b;
  }

  /// Creates a [StateTreeBuilder] with a predefined root state.
  ///
  /// The root state is identified by [rootState], and has an initial child state identified by
  /// [initialChild]. The behavior of the state is configured by calling methods on the
  /// [StateBuilder] that is provided to the [build] callback.
  ///
  /// Any states without an explicit parent that are added to this builder will implicitly be
  /// considered a child of this root state.
  ///
  /// The builder can optionally be given a [label] for diagnostic purposes, and a [logName] which
  /// identifies the builder in log output. If [logName] is unspecifed, [label] will be used instead.
  factory StateTreeBuilder.withRoot(
    StateKey rootState,
    InitialChild initialChild,
    void Function(StateBuilder<void> builder) build, {
    String? label,
    String? logName,
    void Function(StateExtensionBuilder)? extensions,
  }) {
    var b = StateTreeBuilder._(rootState, label, logName);
    var extensionBuilder = b.state(rootState, build, initialChild: initialChild);
    extensions?.call(extensionBuilder);
    return b;
  }

  /// Creates a [StateTreeBuilder] with a root state carrying a value of type [D].
  ///
  /// The root state is identified by [rootState], and has an initial child state identified by
  /// [initialChild]. The behavior of this root state is configured by the [build] callback.
  ///
  /// Any states without an explicit parent that are added to this builder will implicitly be
  /// considered a child of this root state.
  ///
  /// The builder can optionally be given a [label] for diagnostic purposes, and a [logName] which
  /// identifies the builder in log output. If [logName] is unspecifed, [label] will be used instead.
  static StateTreeBuilder withDataRoot<D>(
    DataStateKey<D> rootState,
    InitialData<D> initialData,
    void Function(StateBuilder<D> builder) build,
    InitialChild initialChild, {
    StateDataCodec<D>? codec,
    String? label,
    String? logName,
  }) {
    var b = StateTreeBuilder._(rootState, label, logName);
    b.dataState<D>(
      rootState,
      initialData,
      build,
      initialChild: initialChild,
      codec: codec,
    );
    return b;
  }

  /// Creates the root node of the state tree.
  TreeNode call([TreeBuildContext? context]) => _build(context ?? TreeBuildContext());

  /// Adds to the state tree a description of a state, identified by [stateKey].
  ///
  /// The behavior of the state is configured by calling methods on the [StateBuilder] that is
  /// provided to the [build] callback.
  ///
  /// ```dart
  /// enum Messages { toggle }
  /// var offState = StateKey('off');
  /// var onState = StateKey('on');
  /// var builder = new StateTreeBuilder(initialChild: offState);
  ///
  /// // Describe a state
  /// builder.state(offState, (b) {
  ///   // Define the behavior of the state
  ///   b.onMessageValue(Messages.toggle, (b) => b.goTo(onState));
  /// });
  /// ```
  /// The state can be declared as a child state, by providing a [parent] value referencing the
  /// parent state. If the state is itself a parent state (that is, other states refer to it as a
  /// parent), then [initialChild] must be provided, indicating which child state should be entered
  /// when this state is entered.
  StateExtensionBuilder state(
    StateKey stateKey,
    void Function(StateBuilder<void> builder) build, {
    StateKey? parent,
    InitialChild? initialChild,
  }) {
    var builder = StateBuilder<void>._(
      stateKey,
      InitialData._empty,
      _log,
      parent,
      initialChild,
      isFinal: false,
    );
    build(builder);
    _addState(builder);
    return StateExtensionBuilder._(builder);
  }

  /// Adds to the state tree a description of a final state, identified by [stateKey]. The behavior
  /// of the state is configured by the [build] callback.
  ///
  /// A final state is a terminal state for a state tree. Once a final state has been entered, no
  /// further messsage processing or state transitions will occur.
  ///
  /// A final state never has any child states, and is always a child of the root state.
  void finalState(
    StateKey stateKey,
    void Function(EnterStateBuilder<void> builder) build, {
    StateKey? parent,
  }) {
    var builder = StateBuilder<void>._(
      stateKey,
      InitialData._empty,
      _log,
      parent,
      null,
      isFinal: true,
    );
    build(builder);
    _addState(builder);
  }

  /// Adds to the state tree a description of a data state, identified by [stateKey] and carrying a
  /// value of type [D].
  ///
  /// The behavior of the data state is configured by calling methods on the [StateBuilder]that is
  /// provided to the [build] callback.
  ///
  /// The initial value of the state data is provided by [initialData], and will be evaluated each
  /// time the state is entered.
  ///
  /// ```dart
  /// var countingState = StateKey('counting');
  /// var builder = StateTreeBuilder(initialChild: countingState);
  ///
  /// // Describe a state carrying an integer, with an initial value of 1.
  /// builder.dataState<int>(countingState, InitialData(() => 1), (b) {
  ///   // Define the behavior of the state
  ///   b.onMessageValue<Messages>(Messages.increment, (b) {
  ///     // The updateOwnData callback is called with a context that provides the current message
  ///     // being processed, the and data value for the state.
  ///     b.stay(action: b.act.updateOwnData((ctx) => ctx.data + 1));
  ///   });
  ///   b.onMessageValue<Messages>(Messages.decrement, (b) {
  ///     b.stay(action: b.act.updateOwnData((ctx) => ctx.data - 1));
  ///   });
  /// });
  /// ```
  ///
  /// The state can be declared as a child state, by providing a [parent] value referencing the
  /// parent state. If the state is itself a parent state (that is, other states refer to it as a
  /// parent), then [initialChild] must be provided, indicating which child state should be entered
  /// when this state is entered.
  StateExtensionBuilder dataState<D>(
    DataStateKey<D> stateKey,
    InitialData<D> initialData,
    void Function(StateBuilder<D> builder) build, {
    StateKey? parent,
    InitialChild? initialChild,
    StateDataCodec<dynamic>? codec,
  }) {
    var builder = StateBuilder<D>._(
      stateKey,
      initialData,
      _log,
      parent,
      initialChild,
      isFinal: false,
      codec: codec,
    );
    build(builder);
    _addState(builder);
    return StateExtensionBuilder._(builder);
  }

  /// Adds to the state tree a description of a final data state, identified by [stateKey] and
  /// carrying a value of type [D]. The behavior of the state is configured by the [build] callback.
  ///
  /// A final state is a terminal state for a state tree. Once a final state has been entered, no
  /// further messsage processing or state transitions will occur.
  ///
  /// A final state never has any child states, and is always a child of the root state.
  void finalDataState<D>(
    DataStateKey<D> stateKey,
    InitialData<D> initialData,
    void Function(EnterStateBuilder<D> builder) build, {
    StateKey? parent,
    StateDataCodec<dynamic>? codec,
  }) {
    var builder = StateBuilder<D>._(
      stateKey,
      initialData,
      _log,
      parent,
      null,
      isFinal: true,
      codec: codec,
    );
    build(builder);
    _addState(builder);
  }

  /// Adds to the state tree a description of a machine state, identifed by [stateKey], which will
  /// run a nested state machine.
  ///
  /// When this state is entered, a nested state machine that is produced by [initialMachine] will
  /// be started. By default any messages dispatched to this state will forwarded to the nested
  /// state machine for processing, unless [initialMachine] was created by
  /// [InitialMachine.fromMachine] and the `forwardMessages` parameter was false.
  ///
  /// No transitions from this state will occur until the nested state machine reaches a completion
  /// state. By default, any final state is considered a completion state, but non-final states can
  /// also be completion states by providing [isDone]. This function will be called for each
  /// transition to a non-final state in the nested machine, and if `true` is returned, the nested
  /// state machine will be considered to have completed.
  ///
  /// The machine state carries a state data value of [NestedMachineData]. This value can be
  /// obtained in the same ways as other state data, for example using [CurrentState.dataValue].
  ///
  /// A machine state is always a leaf state. It can be declared as a child state, by providing a
  /// [parent] value. However, all messages will be handled by the machine state until the nested state
  /// machine has entered a final state, and as such the parent state will not recieve any unhandled
  /// messages from the child machine state.
  ///
  /// The behavior of the state when the nested state machine completes is configured with the
  /// [build] callback. [MachineStateBuilder.onMachineDone] can be used to determine the next state
  /// to transition to when the state machione completes. [MachineStateBuilder.onMachineDisposed]
  /// can be used to determine the next state on disposal, but this is typically only needed if
  /// [InitialMachine.fromMachine] is used to return a machine that is disposed by code running
  /// outside of the parent state machine.
  ///
  /// ```dart
  /// class AuthenticatedUser {}
  ///
  /// var authenticateState = StateKey('authenticate');
  /// var authenticatedState = StateKey('authenticated');
  /// var b = StateTreeBuilder(initialChild: authenticateState, logName: 'app');
  ///
  /// StateTreeBuilder authenticateStateTree() {
  ///   var sb = StateTreeBuilder(initialChild: StateKey(''), logName: 'auth');
  ///   // ...Nested state tree definition goes here.
  ///   return sb;
  /// }
  ///
  /// b.machineState(
  ///   authenticateState,
  ///   // Create a nested state machine representing an authentication flow.
  ///   InitialMachine.fromTree((transCtx) => authenticateStateTree()),
  ///   (b) {
  ///     b.onMachineDone(
  ///       (b) => b.goTo(
  ///         authenticatedState,
  ///         // The context property has a CurrentState value, representing the
  ///         // current (final) state of the nested state machine. In this
  ///         // example we assume the final state has a data value representing the
  ///         // user that was authenticated.
  ///         payload: (ctx) => ctx.context.dataValue<AuthenticatedUser>(),
  ///       ),
  ///     );
  ///   },
  /// );
  /// ```
  ///
  ///
  void machineState(
    StateKey stateKey,
    InitialMachine initialMachine,
    void Function(MachineStateBuilder) build, {
    bool Function(Transition transition)? isDone,
    StateKey? parent,
    String? label,
  }) {
    var builder = MachineStateBuilder(
      stateKey,
      initialMachine,
      isDone,
      _log,
      parent,
      isFinal: false,
    );
    build(builder);
    _addState(builder);
  }

  /// Returns a [StateExtensionBuilder] that can be used to extend the state identified by
  /// [stateKey] with additional metadata and filters.
  ///
  /// Throws [StateError] if a state with [stateKey] has not already been defined.
  StateExtensionBuilder extendState(StateKey stateKey) {
    var stateBuilder = _stateBuilders[stateKey];
    return stateBuilder != null
        ? StateExtensionBuilder._(stateBuilder)
        : throw StateError('State $stateKey has not been defined with this $runtimeType');
  }

  /// Calls the [extend] function for each state that has been defined, allowing the states to be
  /// extended with additional metadata and filters.
  ///
  /// The [extend] function is provided with a state key identifying the state to extemd, and a
  /// [StateExtensionBuilder] that can be used to define the extensions.
  StateTreeBuilder extendStates(void Function(StateKey, StateExtensionBuilder) extend) {
    for (var entry in _stateBuilders.entries) {
      extend(entry.key, StateExtensionBuilder._(entry.value));
    }
    return this;
  }

  /// Writes a textual description of the state stree to the [sink]. The specific output format is
  /// controlled by the type of the [formatter].
  ///
  /// ```dart
  /// void formatDOT(StateTreeBuilder treeBuilder) {
  ///   var sink = StringBuffer();
  ///   // Write the state tree Graphviz DOT format.
  ///   treeBuilder.format(sink, DotFormatter());
  /// }
  /// ```
  void format(StringSink sink, StateTreeFormatter formatter) {
    _validate();
    formatter.formatTo(this, sink);
  }

  TreeNode _build(TreeBuildContext context) {
    _validate();

    var rootBuilders = _stateBuilders.values.where((b) => b._stateType == _StateType.root).toList();
    if (rootBuilders.isEmpty) {
      throw StateError('No root builders available');
    } else if (rootBuilders.length > 1) {
      throw StateError('Found multiple root nodes.');
    }

    // If there is a single root, then we have a well formed state tree.
    return rootBuilders.first._toNode(context, _stateBuilders);
  }

  void _addState(_StateBuilder builder) {
    if (_stateBuilders.containsKey(builder.key)) {
      throw StateError("State '${builder.key}' has already been configured.");
    }
    _stateBuilders[builder.key] = builder;
  }

  void _validate() {
    _ensureChildren();

    // Make sure parent/child relationships are consistent.
    for (var entry in _stateBuilders.entries
        .where((e) => e.value._initialChild != null || e.value._children.isNotEmpty)) {
      var initialChild = entry.value._initialChild;
      var children = entry.value._children;
      if (children.isNotEmpty && entry.value is MachineStateBuilder) {
        throw StateTreeDefinitionError(
            'Machine state "${entry.key}" has child state(s): ${children.map((e) => '"$e"').join(', ')}. '
            'Machine states must be leaf states.');
      } else if (initialChild == null) {
        throw StateTreeDefinitionError(
            'Parent state ${entry.key} is missing an initial child state');
      } else if (children.isEmpty) {
        var initialChildBuilder = _stateBuilders[initialChild._initialChildKey];
        if (initialChildBuilder != null) {
          throw StateTreeDefinitionError(
              'Parent state ${entry.key} has initial child $initialChild, but $initialChild has '
              'parent ${initialChildBuilder._parent}');
        } else {
          throw StateTreeDefinitionError(
              'Parent state ${entry.key} is has initial child $initialChild, but $initialChild is '
              'not defined.');
        }
      } else if (initialChild._initialChildKey != null &&
          !children.any((c) => c == initialChild._initialChildKey)) {
        var initChildKey = initialChild._initialChildKey;
        // If an implicit root is used, make sure the initialChild for the root state has no parent specified
        // A more descriptive error message is used in this case.
        if (entry.key == defaultRootKey && _stateBuilders[initChildKey]?._parent != null) {
          var parentKey = _stateBuilders[initChildKey]?._parent;
          throw StateTreeDefinitionError(
              'The initial chlld state $initChildKey specified for this implicit-root $runtimeType has '
              '$parentKey as a parent. The initial child state of the implicit root can not have a parent '
              'specified.');
        } else {
          throw StateTreeDefinitionError(
              'Initial child $initChildKey is not a child state of ${entry.key}');
        }
      }
    }

    // Make sure transitions are to known states
    for (var state in _stateBuilders.values) {
      for (var handlerEntry in state._messageHandlerMap.entries) {
        var handlerInfo = handlerEntry.value;
        var targetStateKey = handlerInfo.info.goToTarget;
        if (targetStateKey != null && !_stateBuilders.containsKey(targetStateKey)) {
          throw StateTreeDefinitionError(
              'State ${state.key} has a transition to unknown state $targetStateKey');
        }
      }
    }
  }

  void _ensureChildren() {
    for (var entry in _stateBuilders.entries.where((e) => e.value._parent != null)) {
      var parentKey = entry.value._parent;
      var parentState = _stateBuilders[parentKey];
      if (parentState == null) {
        throw StateTreeDefinitionError(
            'Unable to find parent state $parentKey for state ${entry.key}');
      } else if (parentState._isFinal) {
        throw StateTreeDefinitionError(
            'State ${entry.key} has final state ${parentState.key} as a parent');
      }
      if (!parentState._children.any((c) => c == entry.value.key)) {
        parentState._children.add(entry.value.key);
      }
    }

    // Check for the root state builder
    var rootState = _stateBuilders[_rootKey];
    if (rootState == null) {
      // This should never happen, since the root state is set in constructors.
      throw StateTreeDefinitionError('Unable to find a root state.');
    }

    // If there are states other than the root that do not have a parent specified (as will happen
    // if the default StateTreeBuilder factory is used), make those states children of the root
    // state.
    var withoutParents = _stateBuilders.values.where((sb) => sb._parent == null).toList();
    for (var withoutParent in withoutParents.where((sb) => sb.key != _rootKey)) {
      rootState._addChild(withoutParent);
    }
  }
}

/// Describes the initial value for a [StateTreeBuilder.dataState] that carries a value of type [D].
class InitialData<D> {
  /// The type of [D].
  final Type dataType = D;
  final D Function(TransitionContext) _initialValue;

  InitialData._(this._initialValue);

  /// Initial data for a 'regular' state (that is, not a data state).
  static final InitialData<void> _empty = InitialData(() {});

  /// Creates the initial data value.
  D call(TransitionContext transCtx) => _initialValue(transCtx);

  /// Creates an [InitialData] that will call the [create] function to obtain the initial data
  /// value. The function is called each time the data state is entered.
  factory InitialData(D Function() create) {
    return InitialData._((_) => create());
  }

  /// Creates an [InitialData] that will call the [create] function, passing the [TransitionContext]
  /// for the transition in progress, to obtain the initial data value. The function is called each
  /// time the data state is entered.
  factory InitialData.run(D Function(TransitionContext) create) {
    return InitialData._(create);
  }

  /// Creates an [InitialData] that produces its value by calling [initialValue] with the payload
  /// provided when entering the state through [channel].
  ///
  /// ```dart
  /// var s1 = StateKey('state1');
  /// var s2 = DataStateKey<S2Data>('state2');
  /// var s2Channel = Channel<String>(s2);
  /// class S2Data {
  ///   String value = '';
  /// }
  /// var builder = StateTreeBuilder(initialChild: parentState);
  ///
  /// builder.state(s1, (b) {
  ///   b.onMessageValue('go', (b) => b.enterChannel(s2Channel, (msgCtx, msg) => 'Hi!'));
  /// });
  ///
  /// builder.dataState<S2Data>(
  ///   s2,
  ///   InitialData.fromChannel(channel, (payload) => S2Data()..value = payload),
  ///   (b) {
  ///     b.onEnter((b) {
  ///       // Will print 'Hi!'
  ///       b.run((transCtx, data) => print(data.value));
  ///     });
  ///   });
  /// ```
  static InitialData<D> fromChannel<D, P>(Channel<P> channel, D Function(P payload) initialValue) {
    return InitialData._((transCtx) {
      try {
        return initialValue(transCtx.payloadOrThrow<P>());
      } catch (e) {
        throw StateError('Failed to obtain inital data of type $D for '
            'channel ${channel.label != null ? '"${channel.label}" ' : ''}'
            'to state ${channel.to}: $e');
      }
    });
  }

  /// Creates an [InitialData] that produces its initial value by calling [initialValue] with
  /// a value of type [DAncestor], obtained by from an ancestor state in the state tree.
  ///
  /// ```dart
  /// class ParentData {
  ///   String value = '';
  ///   ParentData(this.value);
  /// }
  /// var parentState = DataStateKey<ParentData>('parent');
  /// var childState = DataStateKey<int>('child');
  /// var builder = StateTreeBuilder(initialChild: parentState);
  ///
  /// builder.dataState<ParentData>(
  ///   parentState,
  ///   InitialData.value(ParentData('parent value')),
  ///   (_) {},
  ///   initialChild: childState);
  ///
  /// builder.dataState<int>(
  ///   childState,
  ///   // Initialize the state data for the child state from the state data of
  ///   // the parent state
  ///   InitialData.fromAncestor((ParentData ancestorData) => ancestorData.length),
  ///   (_) {},
  ///   parent: parentState
  /// );
  /// ```
  static InitialData<D> fromAncestor<D, DAncestor>(D Function(DAncestor ancData) initialValue) {
    return InitialData._((ctx) => initialValue(ctx.dataValueOrThrow<DAncestor>()));
  }

  /// Creates an [InitialData] that produces its initial value by calling [initialValue] with
  /// a value of type [DAncestor], obtained by from an ancestor state in the state tree, and the
  /// payload value of [channel].
  static InitialData<D> fromChannelAndAncestor<D, DAncestor, P>(
    Channel<P> channel,
    D Function(DAncestor parentData, P payload) initialValue,
  ) {
    return InitialData._(
      (ctx) => initialValue(ctx.dataValueOrThrow<DAncestor>(), ctx.payloadOrThrow<P>()),
    );
  }
}

/// Describes the initial child state of a parent state.
///
/// Because the current state in a tree state machine is always a leaf state, when a parent state is
/// entered, one of its children must immediately be entered as well. The specific child state that
/// is entered is called the initial child of the parent state, and is determined by a [GetInitialChild]
/// function that is run on entering the parent state.
///
/// [InitialChild] allows configuration of [GetInitialChild] as a state is being defined.
/// ```dart
/// var parentState = StateKey('p');
/// var childState1 = StateKey('c1');
/// var childState2 = StateKey('c2');
/// var builder = StateTreeBuilder(initialChild: parentState);
///
/// // Enter childState2 when parentState is entered
/// builder.state(parentState, emptyState, initialChild: InitialChild(childState2));
/// builder.state(childState1, emptyState, parent: parentState);
/// builder.state(childState2, emptyState, parent: parentState);
/// ```
///
class InitialChild {
  final StateKey? _initialChildKey;
  final GetInitialChild _getInitialChild;
  InitialChild._(this._getInitialChild, this._initialChildKey);

  /// Constructs an [InitialChild] indicating that the state identified by [key] should be entered.
  factory InitialChild(StateKey key) {
    return InitialChild._((_) => key, key);
  }

  /// Constructs an [InitialChild] that will run the [getInitialChild] function when the state is
  /// entered in order to determine the initial child,
  ///
  /// Because the behavior of [getInitialChild] is opaque to a [StateTreeFormatter] when
  /// [StateTreeBuilder.format] is called, the graph description produced by the formatter may not
  /// be particularly useful. This method is best avoided if the formatting feature is important to you.
  factory InitialChild.run(GetInitialChild getInitialChild) {
    return InitialChild._(getInitialChild, null);
  }

  /// Returns the key of the child state that should be entered.
  StateKey call(TransitionContext transCtx) => _getInitialChild(transCtx);
}

/// Describes the initial state machine of a [StateTreeBuilder.machineState].
class InitialMachine implements NestedMachine {
  @override
  final bool forwardMessages;
  @override
  final bool disposeMachineOnExit;
  final String? label;
  final FutureOr<TreeStateMachine> Function(TransitionContext) _create;

  InitialMachine._(this._create, this.disposeMachineOnExit, this.forwardMessages, this.label);

  @override
  FutureOr<TreeStateMachine> call(TransitionContext transCtx) => _create(transCtx);

  /// Constructs an [InitialMachine] that will use the state machine produced by the [create]
  /// function as the nested state machine.
  ///
  /// If [disposeOnExit] is true (the default), then the nested state machine will be disposed when the
  /// [StateTreeBuilder.machineState] is exited.
  ///
  /// If [forwardMessages] is true (the default), then the [StateTreeBuilder.machineState] will
  /// forward any messages that are dispatched to it to the nested state machine.
  factory InitialMachine.fromMachine(
    FutureOr<TreeStateMachine> Function(TransitionContext) create, {
    bool disposeOnExit = true,
    bool forwardMessages = true,
    String? label,
  }) {
    return InitialMachine._(create, disposeOnExit, forwardMessages, label);
  }

  /// Constructs an [InitialMachine] that will create and start a nested state machine using
  /// the [StateTreeBuilder] produced by the [create] function.
  factory InitialMachine.fromTree(
    FutureOr<StateTreeBuilder> Function(TransitionContext transCtx) create, {
    String? label,
    String? logName,
  }) {
    return InitialMachine._(
      (ctx) {
        return create(ctx).bind((treeBuilder) {
          return TreeStateMachine(treeBuilder, logName: logName);
        });
      },
      true,
      true,
      label,
    );
  }
}

/// A state builder callback that adds no behavior to a state.
void emptyState<D>(StateBuilder<D> builder) {}

/// A state builder callback that adds no behavior to a final state.
void emptyFinalState<D>(EnterStateBuilder<D> builder) {}

/// Error occurring when an invalid state tree definition was produced.
class StateTreeDefinitionError extends Error {
  final String message;
  StateTreeDefinitionError(this.message);
  @override
  String toString() => "Invalid definition: $message";
}
