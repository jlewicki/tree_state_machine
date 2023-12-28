import 'package:collection/collection.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

enum NodeType { root, interior, leaf }

/// Describes a node in a state tree.
///
/// Pattern-match on subclasses to obtain additional info.
sealed class TreeNodeInfo {
  /// The key identifying this tree node.
  StateKey get key;

  /// {@template TreeNodeInfo.dataCodec}
  /// The [StateDataCodec] that should be used to serialize and deserialize any state data
  /// associated with this node.
  /// {@endtemplate}
  StateDataCodec<dynamic>? get dataCodec;

  /// {@template TreeNodeInfo.metadata}
  /// An unmodifiable map of application-provided metadata associated with this node.
  /// {@endtemplate}
  Map<String, Object> get metadata;

  /// {@template TreeNodeInfo.filters}
  /// An unmodifiable list of [TreeStateFilter]s that should intercept the message and transitions
  /// handlers of the tree state for this node.
  ///
  /// The filters should be applied in the order they occur in this list.
  /// {@endtemplate}
  List<TreeStateFilter> get filters;
}

/// Describes a composite node in a state tree. An composite node has a collection of child nodes.
///
/// Pattern-match on subclasses to obtain additional info.
sealed class CompositeNodeInfo extends TreeNodeInfo {
  /// The child nodes of this node.
  ///
  /// This list is unmodifiable.
  List<TreeNodeInfo> get children;

  /// A function that selects a child node to be entered, when this node is entered.
  GetInitialChild get getInitialChild;
}

/// Describes the root node in a state tree.
sealed class RootNodeInfo extends CompositeNodeInfo {}

/// Describes an interior node in a state tree. An interior node has both a parent and children.
sealed class InteriorNodeInfo extends CompositeNodeInfo {
  /// The parent node of this interior node
  CompositeNodeInfo get parent;
}

/// Describes a leaf node in a state tree. An interior node has a parent, but no children.
sealed class LeafNodeInfo extends TreeNodeInfo {
  /// The parent node of this leaf node
  CompositeNodeInfo get parent;

  /// Indicates if this node represents final state.
  ///
  /// Once a final state has been entered, no further message processing or state transitions will
  /// occur, and the state tree is considered ended and complete.
  bool get isFinalState;
}

/// Utility extensions on [TreeNodeInfo].
// TODO: is there a way to reuse TreeNodeNavigationExtensions
extension TreeNodeInfoNavigationExtensions on TreeNodeInfo {
  /// The parent node of this node, or `null` if it is a root node.
  TreeNodeInfo? parent() {
    return switch (this) {
      LeafNodeInfo(parent: var p) => p,
      InteriorNodeInfo(parent: var p) => p,
      _ => null
    };
  }

  /// Returns the root ancestor node of this node, or this node itself if it is a root node.
  RootNodeInfo root() {
    return selfAndAncestors().firstWhere((e) => e is RootNodeInfo)
        as RootNodeInfo;
  }

  /// Lazily-computes the ancestor nodes of this node.
  Iterable<TreeNodeInfo> ancestors() sync* {
    var nextAncestor = parent();
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent();
    }
  }

  /// Lazily-computes the self-and-ancestor nodes of this node.
  Iterable<TreeNodeInfo> selfAndAncestors() sync* {
    yield this;
    yield* ancestors();
  }

  /// The child node of this node.
  Iterable<TreeNodeInfo> children() {
    return switch (this) {
      CompositeNodeInfo(children: var c) => c,
      _ => <TreeNode>[],
    };
  }

  /// Lazily-computes the descendant nodes of this node, in depth first order
  Iterable<TreeNodeInfo> descendants() sync* {
    for (var child in children()) {
      yield child;
      yield* child.descendants();
    }
  }

  /// Lazily-computes the self-and-descendant nodes of this node, in depth first order
  Iterable<TreeNodeInfo> selfAndDescendants() sync* {
    yield this;
    yield* descendants();
  }

  /// Lazily-computes the descendant leaf nodes of this node.
  Iterable<LeafNodeInfo> leaves() {
    return selfAndDescendants().whereType<LeafNodeInfo>();
  }
}

/// A node in a state tree.
///
/// This close matches [TreeNodeInfo], but keeps mutable and/or internal values out of the public
/// facing interface.
sealed class TreeNode implements TreeNodeInfo {
  TreeNode(
    this.key,
    StateCreator createState, {
    this.dataCodec,
    this.metadata = const {},
    this.filters = const [],
  }) : _lazyState = Lazy<TreeState>(() => createState(key));

  @override
  final StateKey key;

  @override
  final StateDataCodec<dynamic>? dataCodec;

  @override
  final Map<String, Object> metadata;

  @override
  final List<TreeStateFilter> filters;

  /// Lazily computed tree state for this node
  final Lazy<TreeState> _lazyState;

  late final Lazy<TreeNodeDataValue?> _lazyNodeData = _lazyState
      .map((state) => state is DataTreeState ? TreeNodeDataValue(state) : null);

  /// The [TreeState] for this node.
  TreeState get state => _lazyState.value;

  TreeNodeDataValue? get nodeDataValue => _lazyNodeData.value;

  /// The [DataValue] of the [DataTreeState] for this node, or `null` if [state] is not a
  /// [DataTreeState].
  DataValue<dynamic>? get data => _lazyNodeData.value?.data;

  void dispose() {
    if (_lazyNodeData.hasValue) {
      _lazyNodeData.value?.clearData();
    }
    if (_lazyState.hasValue) {
      _lazyState.value.dispose();
    }
  }
}

/// Manages the [DataValue] that is associated with a [TreeNode] whose [TreeNode.state] is a
/// [DataTreeState].
class TreeNodeDataValue {
  TreeNodeDataValue(this._dataState);

  final DataTreeState<dynamic> _dataState;

  Ref<ClosableDataValue<dynamic>?>? _dataValueRef;

  /// The current [DataValue] for this [TreeNodeDataValue], or `null` if the associated data
  /// state is not active
  DataValue<dynamic>? get data => _dataValueRef?.value;

  void initalizeData(TransitionContext transCtx, [Object? initialData]) {
    _dataState.initializeData(<D>() {
      var initialData_ = initialData ?? _dataState.initialData(transCtx);
      assert(initialData == null || initialData is D);
      assert(_dataValueRef == null);
      var ref = Ref(ClosableDataValue<D>(initialData_ as D));
      _dataValueRef = ref;
      return ref;
    });
  }

  void clearData() {
    _dataValueRef?.value?.close();
    _dataValueRef = null;
  }
}

/// A node in a state tree that contains child nodes.
sealed class CompositeTreeNode extends TreeNode implements CompositeNodeInfo {
  CompositeTreeNode(
    super.key,
    super.createState, {
    required this.getInitialChild,
    required this.children,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  @override
  final List<TreeNode> children;

  @override
  final GetInitialChild getInitialChild;

  void visitNodes(void Function(TreeNode) visitNode) {
    void visitNodes_(TreeNode node) {
      visitNode(node);
      var children = switch (node) {
        CompositeTreeNode(children: var c) => c,
        _ => <TreeNode>[],
      };
      for (var child in children) {
        visitNodes_(child);
      }
    }

    return visitNodes_(this);
  }
}

final class RootTreeNode extends CompositeTreeNode implements RootNodeInfo {
  RootTreeNode(
    super.key,
    super.createState, {
    required super.getInitialChild,
    required super.children,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  RootTreeNode withStoppedNode(
    LeafTreeNode Function(RootTreeNode newRoot) createStoppedNode,
  ) {
    var newChildren = List.of(children);
    var root = RootTreeNode(key, (_) => _lazyState.value,
        getInitialChild: getInitialChild,
        children: UnmodifiableListView(newChildren),
        dataCodec: dataCodec,
        filters: filters,
        metadata: metadata);
    for (var child in newChildren) {
      if (child is LeafTreeNode) {
        child._setParent(root);
      } else if (child is InteriorTreeNode) {
        child._setParent(root);
      }
    }
    newChildren.add(createStoppedNode(root));
    return root;
  }
}

/// A node in a state tree that both has a parent node, and contains child nodes.
final class InteriorTreeNode extends CompositeTreeNode
    implements InteriorNodeInfo {
  InteriorTreeNode(
    super.key,
    super.createState, {
    required this.parent,
    required super.getInitialChild,
    required super.children,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  void _setParent(CompositeTreeNode parent) {}

  @override
  final CompositeTreeNode parent;
}

/// A node in a state tree that has a parent, but no child nodes.
///
/// When a state machine receieves a message, it dispatches the message to the current leaf node
/// for processing.
final class LeafTreeNode extends TreeNode implements LeafNodeInfo {
  LeafTreeNode(
    super.key,
    super.createState, {
    required this.parent,
    required this.isFinalState,
    super.dataCodec,
    super.filters,
    super.metadata,
  }) : assert(!isFinalState || parent is RootTreeNode);

  @override
  final CompositeTreeNode parent;

  void _setParent(CompositeTreeNode parent) {}

  @override
  final bool isFinalState;
}

extension TreeNodeNavigationExtensions on TreeNode {
  /// Lazily-compute the self-and-ancestor nodes of this node.
  ///
  /// The first node in the list is this node, and the last is the root node.
  Iterable<TreeNode> selfAndAncestors() sync* {
    yield this;
    yield* ancestors();
  }

  /// Lazily-compute the ancestor nodes of this node.
  ///
  /// The first node in the list is the parent of this node, and the last is the root node.
  Iterable<TreeNode> ancestors() sync* {
    var nextAncestor = parent();
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent();
    }
  }

  /// Lazily-compute the self-and-descendant nodes of this node.
  Iterable<TreeNode> selfAndDescendants() sync* {
    Iterable<TreeNode> visitNodes_(TreeNode node) sync* {
      yield node;
      var children = switch (node) {
        CompositeTreeNode(children: var c) => c,
        _ => <TreeNode>[],
      };
      for (var child in children) {
        yield* visitNodes_(child);
      }
    }

    yield* visitNodes_(this);
  }

  // The parent node of this node, or null if this is a root node.
  TreeNode? parent() {
    return switch (this) {
      LeafTreeNode(parent: var parent) => parent,
      InteriorTreeNode(parent: var parent) => parent,
      _ => null
    };
  }

  /// Finds the self-or-ancestor node that is identified by [stateKey].
  ///
  /// Returns `null` if there is no node that matches the key.
  TreeNode? selfOrAncestorWithKey(StateKey stateKey) {
    return selfAndAncestors().firstWhereOrNull((n) => n.key == stateKey);
  }

  /// Finds the self-or-ancestor node that has a data provider whose data value matches type [D].
  ///
  /// Returns `null` if there is no node that matches the data type.
  TreeNode? selfOrAncestorWithData<D>() {
    return selfAndAncestors().firstWhereOrNull((n) {
      var match = n.data is DataValue && n.data?.value is D ? true : false;
      return match;
    });
  }

  /// Indicates if this node represents a final leaf state.
  bool get isFinalLeaf => switch (this) {
        LeafTreeNode(isFinalState: true) => true,
        _ => false,
      };

  /// Returns `true` if [stateKey] identifies this node, or one of its ancestor nodes.
  bool isSelfOrAncestor(StateKey stateKey) =>
      selfOrAncestorWithKey(stateKey) != null;

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

  /// TODO: simplify this by requiring a DataStateKey
  DataValue<D>? selfOrAncestorDataValue<D>(
      {DataStateKey<D>? key, bool throwIfNotFound = false}) {
    // We cant search
    if (isTypeOfExact<void, D>()) return null;

    var typeofDIsObjectOrDynamic =
        isTypeOfExact<Object, D>() || isTypeOfExact<dynamic, D>();
    // If requested type was Object, then we can't meaningfully search by type. So we can only
    // search by key, and if no key was specified, then we assume the current leaf.
    var key_ = key ?? (typeofDIsObjectOrDynamic ? this.key : null);
    var node = key_ != null
        ? selfOrAncestorWithKey(key_)
        : selfOrAncestorWithData<D>();
    var dataValue = node?.data;
    if (dataValue != null) {
      if (typeofDIsObjectOrDynamic) {
        // In this case we know DataValue<D> is DataValue<Object|dynamic> so it is safe to cast
        return dataValue as DataValue<D>;
      }

      return dataValue is DataValue<D>
          ? dataValue
          : throw StateError(
              'DataValue of type ${dataValue.runtimeType} for requested state ${node!.key} does not have '
              'value of requested type ${TypeLiteral<D>().type}.');
    }

    if (throwIfNotFound) {
      var msg = key_ != null
          ? 'Unable to find data value that matches data type ${TypeLiteral<D>().type} and key $key_'
          : 'Unable to find data value that matches data type ${TypeLiteral<D>().type}';
      throw StateError(msg);
    }

    return null;
  }
}
