import 'package:collection/collection.dart';

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

enum NodeType { rootNode, interiorNode, leafNode, finalLeafNode }

/// Describes the positioning of a tree state within a state tree.
abstract class TreeNodeInfo {
  /// The type of this tree node.
  NodeType get nodeType;

  /// The key identifying this tree node.
  StateKey get key;

  /// The parent node of this true node. Returns `null` if this is a root node.
  TreeNodeInfo? get parent;

  /// Application provided metadata associated with the state.
  Map<String, Object> get metadata;

  /// The child nodes of this node. The list is empty for leaf nodes.
  ///
  /// This list is unmodifiable.
  List<TreeNodeInfo> getChildren();
}

/// A node within a state tree.
///
/// While a [TreeState] defines the message processing behavior of a state, it does not model the
/// location of the state within a state tree (that is, a [TreeState] does not directly know its
/// parent or child states). Instead, [TreeNode] composes together a tree state along with
/// information about the location of the node with the tree.
class TreeNode implements TreeNodeInfo {
  /// The type of this tree node.
  @override
  final NodeType nodeType;

  /// The key identifying this tree node.
  @override
  final StateKey key;

  /// The parent node of this true node. Returns `null` if this is a root node.
  @override
  final TreeNode? parent;

  /// The child nodes of this node. The list is empty for leaf nodes.
  final List<TreeNode> children = [];

  /// Function to identify the child node that should be entered, if this node is entered. Returns
  /// `null` if this node does not have any children.
  final GetInitialChild? getInitialChild;

  // Codec to be used for encoding/decoding state data for this node. Will be null if this is not a
  // node for a data state, or if the state tree was built without serialization support.
  final StateDataCodec<dynamic>? dataCodec;

  /// Lazily computed tree state for this node
  final Lazy<TreeState> _lazyState;

  /// Filters for this node. When available, these filters are invoked, in the order represented by
  /// this list, in lieu of node handlers.
  final List<TreeStateFilter> filters;

  @override
  final Map<String, Object> metadata;

  TreeNode(
    this.nodeType,
    this.key,
    this.parent,
    StateCreator createState,
    this.dataCodec,
    List<TreeStateFilter>? filters,
    Map<String, Object>? metadata, [
    this.getInitialChild,
  ])  : _lazyState = Lazy<TreeState>(() => createState(key)),
        filters = List.unmodifiable(filters ?? List.empty()),
        metadata = Map.unmodifiable(metadata ?? {});

  bool get isRoot => nodeType == NodeType.rootNode;
  bool get isLeaf => nodeType == NodeType.leafNode || nodeType == NodeType.finalLeafNode;
  bool get isInterior => nodeType == NodeType.interiorNode;
  bool get isFinalLeaf => nodeType == NodeType.finalLeafNode;

  /// The [TreeState] for this node.
  TreeState get state => _lazyState.value;

  /// The [DataValue] of the [DataTreeState] for this node, or `null` if [state] is not a
  /// [DataTreeState].
  DataValue<dynamic>? get data {
    var s = state;
    return s is DataTreeState ? s.data : null;
  }

  @override
  List<TreeNodeInfo> getChildren() => UnmodifiableListView(children);

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
    var nextAncestor = parent;
    while (nextAncestor != null) {
      yield nextAncestor;
      nextAncestor = nextAncestor.parent;
    }
  }

  void dispose() {
    if (_lazyState.hasValue) {
      _lazyState.value.dispose();
    }
  }
}

extension TreeNodeNavigationExtensions on TreeNode {
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
    return selfAndAncestors().firstWhereOrNull((n) => n.data is DataValue<D> ? true : false);
  }

  /// Returns `true` if [stateKey] identifies this node, or one of its ancestor nodes.
  bool isSelfOrAncestor(StateKey stateKey) => selfOrAncestorWithKey(stateKey) != null;

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

  DataValue<D>? selfOrAncestorDataValue<D>({DataStateKey<D>? key, bool throwIfNotFound = false}) {
    // We cant search
    if (isTypeOfExact<void, D>()) return null;

    var typeofDIsObjectOrDynamic = isTypeOfExact<Object, D>() || isTypeOfExact<dynamic, D>();
    // If requested type was Object, then we can't meaningfully search by type. So we can only
    // search by key, and if no key was specified, then we assume the current leaf.
    key = key ??
        (typeofDIsObjectOrDynamic
            ? (switch (this.key) { DataStateKey<D>() => this.key as DataStateKey<D>, _ => null })
            : null);
    var node = key != null ? selfOrAncestorWithKey(key) : selfOrAncestorWithData<D>();
    var dataValue = node?.data;
    if (dataValue != null) {
      if (typeofDIsObjectOrDynamic) {
        // In this case we know DataValue<D> is DataValue<Object|dynamic> so it is safe to cast
        return dataValue as DataValue<D>;
      }
      return dataValue is DataValue<D>
          ? dataValue
          : throw StateError(
              'DataValue of type ${dataValue.runtimeType} for requested state ${node!.key} does have '
              'value of requested type ${TypeLiteral<D>().type}.');
    }

    if (throwIfNotFound) {
      var msg = key != null
          ? 'Unable to find data value that matches data type ${TypeLiteral<D>().type} and key $key'
          : 'Unable to find data value that matches data type ${TypeLiteral<D>().type}';
      throw StateError(msg);
    }

    return null;
  }
}
