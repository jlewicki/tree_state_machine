part of tree_builders;

/// Provides methods to describe a state tree.
///
/// States are defined and added to the state tree are described by calling the [state],
/// [dataState], and [finalState] methods.
///
/// ```dart
/// enum Messages { toggle }
/// var offState = StateKey('off');
/// var onState = StateKey('on');
///
/// StateTreeBuilder switchBuilder() {
///   // A simple switch with on and off states
///   var treeBuilder = StateTreeBuilder(initialState: offState)
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
  final Map<StateKey, _StateBuilderBase> _stateBuilders = {};

  StateTreeBuilder._(this._rootKey);

  /// The key identifying the root state that is implicitly added to a state tree, if the
  /// [new StateTreeBuilder] constructor is used.
  static const StateKey defaultRootKey = StateKey('StateTreeBuilderDefaultRootState');

  /// Creates a [StateTreeBuilder] that will build a state tree that starts in the state identified
  /// by [initialState].
  ///
  /// The state tree has an implicit root state, identified by [StateTreeBuilder.defaultRootKey].
  /// This state has no associated behavior, and it is typically safe to ignore its presence.
  factory StateTreeBuilder({required StateKey initialState}) {
    var b = StateTreeBuilder._(defaultRootKey);
    b.state(defaultRootKey, emptyState, initialChild: InitialChild(initialState));
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
  factory StateTreeBuilder.withRoot(
    StateKey rootState,
    void Function(StateBuilder builder) build,
    InitialChild initialChild,
  ) {
    var b = StateTreeBuilder._(rootState);
    b.state(rootState, build, initialChild: initialChild);
    return b;
  }

  /// Creates a [StateTreeBuilder] with a root state carrying a value of type [D].
  ///
  /// The root state is identified by [rootState], and has an initial child state identified by
  /// [initialChild]. The behavior of this root state is configured by the [build] callback.
  ///
  /// Any states without an explicit parent that are added to this builder will implicitly be
  /// considered a child of this root state.
  static StateTreeBuilder withDataRoot<D>(
    StateKey rootState,
    InitialData<D> initialData,
    void Function(DataStateBuilder<D> builder) build,
    InitialChild initialChild, {
    StateDataCodec? codec,
  }) {
    var b = StateTreeBuilder._(rootState);
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
  /// var builder = new StateTreeBuilder(initialState: offState);
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
  void state(
    StateKey stateKey,
    void Function(StateBuilder builder) build, {
    StateKey? parent,
    InitialChild? initialChild,
  }) {
    if (_stateBuilders.containsKey(stateKey)) {
      throw StateError('State $stateKey has already been configured.');
    }
    var builder = _StateBuilder._(stateKey, parent, initialChild);
    build(builder);
    _addState(builder);
  }

  /// Adds to the state tree a description of a data state, identified by [stateKey] and carrying a
  /// value of type [D].
  ///
  /// The behavior of the data state is configured by calling methods on the [DataStateBuilder]
  /// that is provided to the [build] callback.
  ///
  /// The initial value of the state data is provided by [initialData], and will be evaluated each
  /// time the state is entered.
  ///
  /// ```dart
  /// enum Messages { increment, decrement }
  /// var countingState = StateKey('counting');
  /// var builder = new StateTreeBuilder(initialState: countingState);
  ///
  /// // Describe a state carrying an integer, with an initial value of 1.
  /// builder.dataState<int>(
  ///   countingState,
  ///   InitialData.value(1),
  ///   (b) {
  ///     // Define the behavior of the state
  ///     b.onMessageValue<Messages>(Messages.increment, (b) {
  ///       b.stay(action: b.act.updateData((ctx, msg, counter) => counter + 1));
  ///     });
  ///     b.onMessageValue<Messages>(Messages.decrement, (b) {
  ///       b.stay(action: b.act.updateData((ctx, msg, counter) => counter - 1));
  ///     });
  ///   });
  /// ```
  ///
  /// The state can be declared as a child state, by providing a [parent] value referencing the
  /// parent state. If the state is itself a parent state (that is, other states refer to it as a
  /// parent), then [initialChild] must be provided, indicating which child state should be entered
  /// when this state is entered.
  void dataState<D>(
    StateKey stateKey,
    InitialData<D> initialData,
    void Function(DataStateBuilder<D> builder) build, {
    StateKey? parent,
    InitialChild? initialChild,
    StateDataCodec? codec,
  }) {
    if (_stateBuilders.containsKey(stateKey)) {
      throw StateError('State $stateKey has already been configured.');
    }
    var builder = _DataStateBuilder<D>._(stateKey, initialData, codec, parent, initialChild, false);
    build(builder);
    _addState(builder);
  }

  /// Adds to the state tree a description of a final state, identified by [stateKey]. The behavior
  /// of the state is configured by the [build] callback.
  ///
  /// A final state is a terminal state for a state tree. Once a final state has been entered, no
  /// further messsage processing or state transitions will occur.
  ///
  /// A final state never has any child states, and is always a child of the root state.
  void finalState(StateKey stateKey, void Function(FinalStateBuilder builder) build) {
    var builder = _StateBuilder._(stateKey, null, null, true);
    build(builder);
    _addState(builder);
  }

  /// Adds to the state tree a description of a final data state, identified by [stateKey] and
  /// carrying a value of type [D]. The behavior of the state is configured by the [build] callback.
  ///
  /// A final state is a terminal state for a state tree. Once a final state has been entered, no
  /// further messsage processing or state transitions will occur.
  ///
  /// A final state never has any child states, and is always a child of the root state.
  void finalDataState<D>(
    StateKey stateKey,
    InitialData<D> initialData,
    void Function(FinalDataStateBuilder<D> builder) build, {
    StateDataCodec? codec,
  }) {
    var builder = _DataStateBuilder<D>._(stateKey, initialData, codec, null, null, true);
    build(builder);
    _addState(builder);
  }

  /// Adds to the state tree a description of a machine state, identifed by [stateKey], and which
  /// will run a nested state machine.
  ///
  /// When this state is entered, a nested state machine that is produced by [initialMachine], will
  /// be started, and any messages dispatched to this stated will forwarded to the nested state
  /// machine.
  ///
  /// No transitions from this state will occur until the nested state machine end by reaching a
  /// final state. When this occurs, [onDone] will be called with the final [CurrentState] of the
  /// nested state machine, which returns the key of the next state to transition to.
  ///
  /// The state can be declared as a child state, by providing a [parent] value referencing the
  /// parent state.
  void machineState(
    StateKey stateKey,
    InitialMachine initialMachine,
    FutureOr<StateKey> Function(CurrentState finalState) onDone, {
    StateKey? parent,
    String? label,
  }) {
    _addState(_MachineStateBuilder(stateKey, initialMachine, onDone, parent));
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

  TreeNode call(TreeBuildContext context) => build(context);

  TreeNode build(TreeBuildContext context) {
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

  void _addState(_StateBuilderBase builder) {
    if (_stateBuilders.containsKey(builder.key)) {
      throw StateError('A state with ${builder.key} has already been added to this state tree.');
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
      if (initialChild == null) {
        throw StateError('Parent state ${entry.key} is missing an initial child state');
      } else if (children.isEmpty) {
        var initialChildBuilder = _stateBuilders[initialChild];
        if (initialChildBuilder != null) {
          throw StateError(
              'Parent state ${entry.key} has initial child $initialChild, but $initialChild has '
              'parent ${initialChildBuilder._parent}');
        } else {
          throw StateError(
              'Parent state ${entry.key} is has initial child $initialChild, but $initialChild is '
              'not defined.');
        }
      } else if (initialChild._initialChildKey != null &&
          !children.any((c) => c == initialChild._initialChildKey)) {
        throw StateError('Initial child $initialChild is not a child state of ${entry.key}');
      }
    }

    // Make sure transitions are to known states
    for (var state in _stateBuilders.values) {
      for (var handlerEntry in state._messageHandlerMap.entries) {
        var handlerInfo = handlerEntry.value;
        var targetStateKey = handlerInfo.tryGetTargetState();
        if (targetStateKey != null && !_stateBuilders.containsKey(targetStateKey)) {
          throw StateError('State ${state.key} has a transition to unknown state $targetStateKey');
        }
      }
    }
  }

  void _ensureChildren() {
    for (var entry in _stateBuilders.entries.where((e) => e.value._parent != null)) {
      var parentKey = entry.value._parent;
      var parentState = _stateBuilders[parentKey];
      if (parentState == null) {
        throw StateError('Unable to find parent state $parentKey for state ${entry.key}');
      } else if (parentState.isFinal) {
        throw StateError('State ${entry.key} has final state ${parentState.key} as a parent');
      }
      if (!parentState._children.any((c) => c == entry.value.key)) {
        parentState._children.add(entry.value.key);
      }
    }

    // Check for the root state builder
    var rootState = _stateBuilders[_rootKey];
    if (rootState == null) {
      // This should never happen, since the root state is set in constructors.
      throw StateError('Unable to find a root state.');
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

/// A function that adds no behavior to a state.
void emptyState(StateBuilder builder) {}

/// A function that adds no behavior to a data state.
void emptyDataState<D>(DataStateBuilder<D> builder) {}

/// A function that adds no behavior to a final state.
void emptyFinalState(FinalStateBuilder builder) {}

/// A function that adds no behavior to a final data state.
void emptyFinalDataState<D>(FinalDataStateBuilder<D> builder) {}

//==================================================================================================
//
// InitialData
//

/// Provides an initial value for a data state that carries a value of type [D].
class InitialData<D> {
  final D Function(TransitionContext) _initialValue;
  InitialData._(this._initialValue);

  /// Creates an [InitialData] that will call the [create] function to obtain the initial data
  /// value. The function is called each time the data state is entered.
  factory InitialData(D Function() create) {
    return InitialData._((_) => create());
  }

  /// Creates an [InitialData] that produces its value by calling [initialValue] with the payload
  /// provided when entering the state through [channel].
  ///
  /// ```dart
  /// var s1 = StateKey('state1');
  /// var s2 = StateKey('state2');
  /// var s2Channel = Channel<String>(s2);
  /// class S2Data {
  ///   String value = '';
  /// }
  /// var builder = StateTreeBuilder(initialState: parentState);
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
    return InitialData._((transCtx) => initialValue(transCtx.payloadOrThrow<P>()));
  }

  /// Creates an [InitialData] that produces its initial value by calling [initialValue] with
  /// a value of type [DAncestor], obtained by from an ancestor state in the state tree.
  ///
  /// ```dart
  /// class ParentData {
  ///   String value = '';
  ///   ParentData(this.value);
  /// }
  /// var parentState = StateKey('parent');
  /// var childState = StateKey('child');
  /// var builder = StateTreeBuilder(initialState: parentState);
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
      Channel<P> channel, D Function(DAncestor parentData, P payload) map) {
    return InitialData._((ctx) => map(ctx.dataValueOrThrow<DAncestor>(), ctx.payloadOrThrow<P>()));
  }

  D eval(TransitionContext transCtx) => _initialValue(transCtx);
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
/// var builder = StateTreeBuilder(initialState: parentState);
///
/// // Enter childState2 when parentState is entered
/// builder.state(parentState, emptyState, initialChild: InitialChild.key(childState2));
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

  StateKey eval(TransitionContext transCtx) => _getInitialChild(transCtx);
}

class InitialMachine {
  final TreeStateMachine Function(TransitionContext) _create;

  InitialMachine(this._create);

  factory InitialMachine.fromTree(StateTreeBuilder Function(TransitionContext transCtx) create) {
    return InitialMachine((ctx) {
      var tree = create(ctx);
      return TreeStateMachine(tree);
    });
  }
}
