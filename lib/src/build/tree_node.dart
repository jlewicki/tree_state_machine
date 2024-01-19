import 'dart:async';

import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:tree_state_machine/build.dart';
import 'package:tree_state_machine/src/machine/machine.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

enum NodeType { root, interior, leaf }

class TreeNode {
  TreeNode(this.info, {required this.parent, required List<TreeNode> children})
      : children = UnmodifiableListView(children),
        resources = TreeNodeResources(info.key, info.createState);
  final TreeNodeInfo info;
  final TreeNode? parent;
  final List<TreeNode> children;
  final TreeNodeResources resources;

  NodeType get nodeType {
    if (parent == null) return NodeType.root;
    if (children.isEmpty) return NodeType.leaf;
    return NodeType.interior;
  }

  StateKey get key => info.key;

  /// The [TreeState] for this node.
  TreeState get state => resources.state;

  /// The [DataValue] of the [DataTreeState] for this node, or `null` if [state]
  /// is not a [DataTreeState].
  DataValue<dynamic>? get data => resources.nodeData?.data;

  bool get isFinal =>
      switch (info) { LeafNodeInfo(isFinalState: true) => true, _ => false };

  void dispose() {
    resources.dispose();
  }
}

/// Manages the [DataValue] that is associated with a [TreeNode] whose
/// [TreeNode.state] is a [DataTreeState].
class TreeNodeDataValue {
  TreeNodeDataValue(this._dataState);

  final DataTreeState<dynamic> _dataState;

  Ref<ClosableDataValue<dynamic>?>? _dataValueRef;

  /// The current [DataValue] for this [TreeNodeDataValue], or `null` if the
  /// associated data state is not active
  DataValue<dynamic>? get data => _dataValueRef?.value;

  void initalizeData(TransitionContext transCtx, [Object? initialData]) {
    _dataState.initializeData(<D>() {
      assert(initialData == null || initialData is D);
      var initialData_ = initialData ?? _dataState.initialData(transCtx);
      if (initialData_ == null &&
          !(transCtx as MachineTransitionContext).hasRedirect) {
        var msg =
            "Initial data for state '${transCtx.handlingState}' returned null. "
            "Null return values are only permitted if "
            "TransitionContext.redirectTo is also called when computing the "
            "initial data value.";
        throw StateTreeDefinitionError(msg);
      }
      assert(_dataValueRef == null);
      var ref = Ref(ClosableDataValue<D>.lazy(() =>
          // This will throw if initialData_ is null, but that will only occur
          // if a direct is also requested, in which case this function will
          // not be executed.
          initialData_ as D));
      _dataValueRef = ref;
      return ref;
    });
  }

  void clearData() {
    _dataValueRef?.value?.close();
    _dataValueRef = null;
  }
}

class TreeNodeResources {
  TreeNodeResources._(this._key, this._lazyState, this._lazyNodeData);

  factory TreeNodeResources(StateKey key, StateCreator createState) {
    var lazyState = Lazy<TreeState>(() => createState(key));
    var lazyNodeData =
        lazyState.map((s) => s is DataTreeState ? TreeNodeDataValue(s) : null);
    return TreeNodeResources._(key, lazyState, lazyNodeData);
  }

  final StateKey _key;
  final Lazy<TreeState> _lazyState;
  final Lazy<TreeNodeDataValue?> _lazyNodeData;
  final List<Timer> _timers = [];
  Logger? _log;

  TreeState get state => _lazyState.value;

  TreeNodeDataValue? get nodeData => _lazyNodeData.value;

  void addTimer(Timer timer) {
    _timers.add(timer);
  }

  void cancelTimers() {
    if (_timers.isNotEmpty) {
      _log?.fine("Canceling timers for state '$_key'");
      for (final timer in _timers) {
        timer.cancel();
      }
    }
  }

  void dispose() {
    cancelTimers();
    if (_lazyNodeData.hasValue) {
      _lazyNodeData.value?.clearData();
    }
    if (_lazyState.hasValue) {
      _lazyState.value.dispose();
    }
  }
}

extension TreeNodeNavigationExtensions on TreeNode {
  /// Returns the root ancestor node of this node, or this node itself if it is
  /// a root node.
  RootNodeInfo root() {
    return selfAndAncestors().firstWhere((e) => e is RootNodeInfo)
        as RootNodeInfo;
  }

  /// Lazily-computes the ancestor nodes of this node.
  Iterable<TreeNode> ancestors() sync* {
    var nextAncestor = parent;
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent;
    }
  }

  /// Returns a value indicating if [node] is a self-or-ancestor node of this
  /// node.
  bool isSelfOrAncestor(TreeNode node) {
    return selfAndAncestors().contains(node);
  }

  /// Lazily-computes the self-and-ancestor nodes of this node.
  Iterable<TreeNode> selfAndAncestors() sync* {
    yield this;
    yield* ancestors();
  }

  /// Lazily-computes the descendant nodes of this node, in depth first order
  Iterable<TreeNode> descendants() sync* {
    for (var child in children) {
      yield child;
      yield* child.descendants();
    }
  }

  /// Lazily-computes the self-and-descendant nodes of this node, in depth first
  /// order
  Iterable<TreeNode> selfAndDescendants() sync* {
    yield this;
    yield* descendants();
  }

  /// Lazily-computes the descendant leaf nodes of this node.
  Iterable<TreeNode> leaves() {
    return selfAndDescendants().where((d) => d.children.isEmpty);
  }

  /// Finds the least common ancestor (LCA) between this and the [other] node.
  TreeNode lcaWith(TreeNode other) {
    // Short circuit in case nodes are the same.
    if (other.key == key) return this;

    var i1 = selfAndAncestors().toList().reversed.iterator;
    var i2 = other.selfAndAncestors().toList().reversed.iterator;
    TreeNode? lca;
    while (i1.moveNext() && i2.moveNext()) {
      lca = i1.current.key == i2.current.key ? i1.current : lca;
    }
    assert(lca != null, 'LCA must not be null');
    return lca!;
  }

  /// Finds the self-or-ancestor node that is identified by [stateKey].
  ///
  /// Returns `null` if there is no node that matches the key.
  TreeNode? selfOrAncestorWithKey(StateKey stateKey) {
    return selfAndAncestors().firstWhereOrNull((n) => n.key == stateKey);
  }

  DataValue<D>? selfOrAncestorDataValue<D>(
    DataStateKey<D> key, {
    bool throwIfNotFound = false,
  }) {
    // If requested type was Object, then we can't meaningfully search by type.
    // So we can only search by key, and if no key was specified, then we assume
    //the current leaf.
    var node = selfOrAncestorWithKey(key);
    var dataValue = node?.data;
    if (dataValue != null) {
      return dataValue is DataValue<D>
          ? dataValue
          : throw StateError(
              'DataValue of type ${dataValue.runtimeType} for requested state $key does not have '
              'value of requested type $D.');
    }

    if (throwIfNotFound) {
      var msg =
          'Unable to find data value that matches data type $D and key $key';
      throw StateError(msg);
    }

    return null;
  }
}
