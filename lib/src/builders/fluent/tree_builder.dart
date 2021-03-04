part of fluent_tree_builders;

/// Provides methods for describing the states in a state tree.
class StateTreeBuilder implements NodeBuilder<RootNode> {
  final StateKey _rootKey;
  final StateKey _initialStateKey;
  final Map<StateKey, StateBuilder> _stateBuilders = {};

  StateTreeBuilder._(this._rootKey, this._initialStateKey);

  /// Creates a [StateTreeBuilder].
  factory StateTreeBuilder() => StateTreeBuilder._(null, null);

  /// Creates a [StateTreeBuilder] with an implicit root state, with an initial child state
  /// identified by [initialStateKey].
  ///
  /// Any states without an explicit parent that are added to this builder will implicitly be
  /// considered a child of this state.
  factory StateTreeBuilder.flat(StateKey initialStateKey) =>
      StateTreeBuilder._(StateKey.named('ImplicitRoot'), initialStateKey);

  /// Creates a [StateTreeBuilder] with a predefined root state.
  ///
  /// The root state is identified by [rootStateKey], and has an initial child state identified by
  /// [initialStateKey].
  ///
  /// Any states without an explicit parent that are added to this builder will implicitly be
  /// considered a child of this state. The behavior of this root state can be defined by calling
  /// [state] with [rootStateKey] as the key.
  factory StateTreeBuilder.rooted(StateKey rootStateKey, StateKey initialStateKey) =>
      StateTreeBuilder._(rootStateKey, initialStateKey);

  /// Adds a state, identified by [stateKey], to the state tree.
  ///
  /// The behavior of the state should be described by using the methods of the returned
  /// [StateBuilder].
  StateBuilder state(StateKey stateKey) {
    if (stateKey == null) {
      throw ArgumentError.notNull('stateKey');
    }

    if (_stateBuilders.containsKey(stateKey)) {
      throw new StateError('State has already been configured');
    }
    var stateBuilder = new StateBuilder._(stateKey);
    _stateBuilders[stateKey] = stateBuilder;
    return stateBuilder;
  }

  /// Adds a data state, identified by [key], and with data type [D], to the state tree.
  ///
  /// The behavior of the state must be described by using the methods of the returned
  /// [DataStateBuilder].
  DataStateBuilder<D> dataState<D>(
    StateKey stateKey, {
    DataProvider<D> Function() createProvider,
    D Function() initialData,
  }) {
    if (_stateBuilders.containsKey(stateKey)) {
      throw StateError('State has already been configured');
    }
    if (createProvider != null && initialData != null) {
      throw ArgumentError('Only one of createProvider and initialData can be provided');
    }

    var stateBuilder = new DataStateBuilder<D>._(stateKey);
    stateBuilder._createProvider = createProvider;
    if (initialData != null) {
      stateBuilder._createProvider = () => OwnedDataProvider<D>(initialData);
    }
    _stateBuilders[stateKey] = stateBuilder;
    return stateBuilder;
  }

  /// Adds a final state, identified by [stateKey], to the state tree.
  ///
  /// When entered, a final state will never process any messages or transition
  /// to a different state.
  FinalStateBuilder finalState(StateKey stateKey) {
    if (stateKey == null) {
      throw ArgumentError.notNull('stateKey');
    }

    if (_stateBuilders.containsKey(stateKey)) {
      throw new StateError('State has already been configured');
    }
    var finalBuilder = FinalStateBuilder._(stateKey);
    _stateBuilders[stateKey] = finalBuilder._stateBuilder;
    return finalBuilder;
  }

  /// Returns a string containing a description of the state tree in the DOT graph format.
  ///
  /// This graph can be rendered using a tool that supports the DOT format, for example
  /// [webgraphviz](http://www.webgraphviz.com/).
  ///
  /// For details on DOT syntax, visit the [Graphviz](https://graphviz.org/documentation/) site.
  String toDot({String graphName, String Function(StateKey key) labelState}) {
    _ensureChildren();
    _validateTree();
    return _DotFormatter(_stateBuilders, graphName: graphName, getStateName: labelState).toDot();
  }

  @override
  TreeNode build(TreeBuildContext context) {
    _ensureChildren();
    _validateTree();

    // Find root nodes
    NodeBuilder<RootNode> treeBuilder;
    var rootBuilders = _stateBuilders.values.where((b) => b._stateType == _StateType.root).toList();

    if (rootBuilders.length == 0) {
      // If there are no roots, but many leaves
    } else if (rootBuilders.length == 1) {
      // If there is a single root, then we have a well formed state tree.
      var finalBuilders = _stateBuilders.values.where((b) => b.isFinal).toList();
      treeBuilder = rootBuilders[0]._toRootNode(_stateBuilders, finalBuilders);
    } else {
      throw StateError('Found multiple root nodes.');
    }

    return treeBuilder.build(context);
  }

  void _validateTree() {
    // Make sure parent/child relationships are consistent.
    for (var entry in _stateBuilders.entries.where((e) => e.value._children.isNotEmpty)) {
      if (entry.value._initialChild == null) {
        throw StateError('Parent state ${entry.key} is missing an initial child state');
      }
      if (!entry.value._children.any((c) => c == entry.value._initialChild)) {
        throw StateError(
            'Intial child ${entry.value._initialChild} is not a child state of ${entry.key}');
      }
      // TODO: check for circular references in parent chain
    }

    // Make sure transitions are to known states
    for (var state in _stateBuilders.values) {
      for (var handlerEntry in state._messageHandlerMap.entries) {
        for (var handlerInfo in handlerEntry.value) {
          if (handlerInfo.targetState != null) {
            var targetState = _stateBuilders[handlerInfo.targetState];
            if (targetState == null) {
              throw new StateError(
                  'State ${state.key} has a transition to unknown state ${handlerInfo.targetState}');
            }
          }
        }
      }
    }

    // Make sure data states have a provider
    for (var dataState in _stateBuilders.values.where((s) => s is DataStateBuilder)) {
      if ((dataState as DataStateBuilder)._createProvider == null) {
        throw StateError('Data state ${dataState.key} does not have an data provider.');
      }
    }
  }

  void _ensureChildren() {
    for (var entry in _stateBuilders.entries.where((e) => e.value._parent != null)) {
      var parentState = _stateBuilders[entry.value._parent];
      if (parentState == null) {
        throw StateError('Unable to find parent state ${parentState} for state ${entry.key}');
      }
      if (!parentState._children.any((c) => c == entry.value.key)) {
        parentState._children.add(entry.value.key);
      }
    }

    // Check for a root node
    var withoutParents = _stateBuilders.values.where((sb) => sb._parent == null).toList();
    if (withoutParents.isEmpty) {
      throw StateError('Unable to find a root state, since every state has a parent.');
    }

    // Make the root state the the parent of the states that do not have a parent explicitly
    // specified.
    if (_rootKey != null) {
      var rootState = _stateBuilders[this._rootKey] ?? state(_rootKey);
      rootState._initialChild = rootState._initialChild ?? _initialStateKey;
      for (var withoutParent in withoutParents.where((sb) => sb.key != _rootKey)) {
        withoutParent.withParent(this._rootKey);
        rootState._children.add(withoutParent.key);
      }
    }
  }
}
