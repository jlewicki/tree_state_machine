part of '../../../declarative_builders.dart';

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
/// DeclarativeStateTreeBuilder switchBuilder() {
///   // A simple switch with on and off states
///   var treeBuilder = DeclarativeStateTreeBuilder(initialChild: offState)
///   treeBuilder.state(offState, (b) {
///     b.onMessageValue(Messages.toggle, (b) => b.goTo(onState));
///   })
///   treeBuilder.state(onState, (b) {
///     b.onMessageValue(Messages.toggle, (b) => b.goTo(offState));
///   });
///   return treeBuilder;
/// }
/// ```
/// Once a [DeclarativeStateTreeBuilder] has been initialized with the desired states, it can be used to create
/// a state machine. The state machine will create and manage its own instance of the state tree
/// defined by the builder.
///
/// ```dart
///  var declBuilder = switchBuilder();
///  var stateMachine = TreeStateMachine(StateTreeBuilder(declBuilder));
/// ```
///
/// Note that a single state tree builder instance can be used to create multiple state machine
/// instances.
///
/// A textual description of the state tree can be produced by calling [format] method, passing a
/// [StateTreeFormatter] (for example a [DotFormatter]) representing the desired output format.
class DeclarativeStateTreeBuilder implements StateTreeBuildProvider {
  DeclarativeStateTreeBuilder._(this._rootKey, this.label, String? logName)
      : logName = logName ?? label;

  /// Creates a [DeclarativeStateTreeBuilder] that will build a state tree that starts in the state identified
  /// by [initialChild].
  ///
  /// The state tree has an implicit root state, identified by [DeclarativeStateTreeBuilder.defaultRootKey].
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
  factory DeclarativeStateTreeBuilder({
    required StateKey initialChild,
    String? label,
    String? logName,
  }) {
    var b = DeclarativeStateTreeBuilder._(defaultRootKey, label, logName);
    b.state(
      defaultRootKey,
      emptyState,
      initialChild: InitialChild(initialChild),
    );
    return b;
  }

  /// Creates a [DeclarativeStateTreeBuilder] with a predefined root state.
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
  factory DeclarativeStateTreeBuilder.withRoot(
    StateKey rootState,
    InitialChild initialChild,
    void Function(StateBuilder<void> builder) build, {
    String? label,
    String? logName,
    void Function(StateExtensionBuilder)? extensions,
  }) {
    var b = DeclarativeStateTreeBuilder._(rootState, label, logName);
    var extensionBuilder = b.state(
      rootState,
      build,
      initialChild: initialChild,
    );
    extensions?.call(extensionBuilder);
    return b;
  }

  /// The key identifying the root state that is implicitly added to a state tree, if the
  /// [StateTreeBuilder.new] constructor is used.
  static const StateKey defaultRootKey = StateKey('<!RootState!>');

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

  final StateKey _rootKey;
  final Map<StateKey, _StateBuilder> _stateBuilders = {};
  late final Logger _log = Logger(
    'tree_state_machine.StateTreeBuilder${logName != null ? '.${logName!}' : ''}',
  );

  @override
  RootNodeInfo createRootNodeInfo() {
    _validate();
    var rootStateBuilder = _getStateBuilder(_rootKey);
    var rootBuildInfo = rootStateBuilder.toTreeNodeInfo(
      (childKey) => _stateBuilders[childKey]!,
      null,
    );
    return rootBuildInfo as RootNodeInfo;
  }

  StateTreeBuilder toTreeBuilder() {
    return StateTreeBuilder(this, label: label, logName: logName);
  }

  // /// Creates the root node of the state tree.
  TreeNode call([TreeBuildContext? context]) {
    var treeBuilder = StateTreeBuilder(this);
    return treeBuilder.build(context ?? TreeBuildContext());
  }

  /// Creates a [DeclarativeStateTreeBuilder] with a root state carrying a value of type [D].
  ///
  /// The root state is identified by [rootState], and has an initial child state identified by
  /// [initialChild]. The behavior of this root state is configured by the [build] callback.
  ///
  /// Any states without an explicit parent that are added to this builder will implicitly be
  /// considered a child of this root state.
  ///
  /// The builder can optionally be given a [label] for diagnostic purposes, and a [logName] which
  /// identifies the builder in log output. If [logName] is unspecifed, [label] will be used instead.
  static DeclarativeStateTreeBuilder withDataRoot<D>(
    DataStateKey<D> rootState,
    InitialData<D> initialData,
    void Function(StateBuilder<D> builder) build,
    InitialChild initialChild, {
    StateDataCodec<D>? codec,
    String? label,
    String? logName,
  }) {
    var b = DeclarativeStateTreeBuilder._(rootState, label, logName);
    b.dataState<D>(
      rootState,
      initialData,
      build,
      initialChild: initialChild,
      codec: codec,
    );
    return b;
  }

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
      InitialData<void>(() {}),
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
      InitialData<void>(() {}),
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
    DataStateKey<NestedMachineData> stateKey,
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
        : throw StateError(
            'State $stateKey has not been defined with this $runtimeType');
  }

  /// Calls the [extend] function for each state that has been defined, allowing the states to be
  /// extended with additional metadata and filters.
  ///
  /// The [extend] function is provided with a state key identifying the state to extemd, and a
  /// [StateExtensionBuilder] that can be used to define the extensions.
  DeclarativeStateTreeBuilder extendStates(
      void Function(StateKey, StateExtensionBuilder) extend) {
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

  // TreeNode _buildNode(TreeBuildContext context, _StateBuilder stateBuilder) {
  //   var nodeBuildInfo = stateBuilder.toTreeNodeInfo(_makeChildNodeBuilder);
  //   return switch (nodeBuildInfo) {
  //     RootNodeInfo() => context.buildRoot(nodeBuildInfo),
  //     InteriorNodeInfo() => context.buildInterior(nodeBuildInfo),
  //     LeafNodeInfo() => context.buildLeaf(nodeBuildInfo),
  //   };
  // }

  // TreeNodeBuilder _makeChildNodeBuilder(StateKey childStateKey) {
  //   var childBuilder = _getStateBuilder(childStateKey);
  //   return (childCtx) => _buildNode(childCtx, childBuilder);
  // }

  _StateBuilder _getStateBuilder(StateKey key) {
    var stateBuilder = _stateBuilders[key];
    assert(stateBuilder != null);
    return stateBuilder!;
  }

  void _addState(_StateBuilder builder) {
    if (_stateBuilders.containsKey(builder.key)) {
      throw StateTreeDefinitionError(
          "State '${builder.key}' has already been configured.");
    }
    _stateBuilders[builder.key] = builder;
  }

  void _validate() {
    _ensureChildren();

    // Make sure parent/child relationships are consistent.
    for (var entry in _stateBuilders.entries.where(
        (e) => e.value._initialChild != null || e.value._children.isNotEmpty)) {
      var initialChild = entry.value._initialChild;
      var initialChildKey =
          initialChild is InitialChildByKey ? initialChild.initialChild : null;
      var children = entry.value._children;
      if (children.isNotEmpty && entry.value is MachineStateBuilder) {
        throw StateTreeDefinitionError(
            'Machine state "${entry.key}" has child state(s): ${children.map((e) => '"$e"').join(', ')}. '
            'Machine states must be leaf states.');
      } else if (initialChild == null) {
        throw StateTreeDefinitionError(
            'Parent state ${entry.key} is missing an initial child state');
      } else if (children.isEmpty) {
        var initialChildBuilder =
            initialChildKey != null ? _stateBuilders[initialChildKey] : null;
        if (initialChildBuilder != null) {
          throw StateTreeDefinitionError(
              'Parent state ${entry.key} has initial child $initialChild, but $initialChild has '
              'parent ${initialChildBuilder._parent}');
        } else {
          throw StateTreeDefinitionError(
              'Parent state ${entry.key} is has initial child $initialChild, but $initialChild is '
              'not defined.');
        }
      } else if (initialChildKey != null &&
          !children.any((c) => c == initialChildKey)) {
        // If an implicit root is used, make sure the initialChild for the root state has no parent specified
        // A more descriptive error message is used in this case.
        if (entry.key == defaultRootKey &&
            _stateBuilders[initialChildKey]?._parent != null) {
          var parentKey = _stateBuilders[initialChildKey]?._parent;
          throw StateTreeDefinitionError(
              'The initial chlld state $initialChildKey specified for this implicit-root $runtimeType has '
              '$parentKey as a parent. The initial child state of the implicit root can not have a parent '
              'specified.');
        } else {
          throw StateTreeDefinitionError(
              'Initial child $initialChildKey is not a child state of ${entry.key}');
        }
      }
    }

    // Make sure transitions are to known states
    for (var state in _stateBuilders.values) {
      for (var handlerEntry in state._messageHandlerMap.entries) {
        var handlerInfo = handlerEntry.value;
        var targetStateKey = handlerInfo.info.goToTarget;
        if (targetStateKey != null &&
            !_stateBuilders.containsKey(targetStateKey)) {
          throw StateTreeDefinitionError(
              'State ${state.key} has a transition to unknown state $targetStateKey');
        }
      }
    }
  }

  void _ensureChildren() {
    for (var entry
        in _stateBuilders.entries.where((e) => e.value._parent != null)) {
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
    var withoutParents =
        _stateBuilders.values.where((sb) => sb._parent == null).toList();
    for (var withoutParent
        in withoutParents.where((sb) => sb.key != _rootKey)) {
      rootState._addChild(withoutParent);
    }
  }
}

/// A state builder callback that adds no behavior to a state.
void emptyState<D>(StateBuilder<D> builder) {}

/// A state builder callback that adds no behavior to a final state.
void emptyFinalState<D>(EnterStateBuilder<D> builder) {}
