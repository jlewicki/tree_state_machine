import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';
import 'package:collection/collection.dart';

enum NodeType { rootNode, interiorNode, leafNode, finalLeafNode }

/// A node within a state tree.
///
/// While a [TreeState] defines the message processing behavior of a state, it does not model the
/// location of the state within a state tree (that is, a [TreeState] does not directly know its
/// parent or child states). Instead, [TreeNode] composes together a tree state along with
/// information about the location of the node with the tree.
class TreeNode {
  /// The type of this tree node.
  final NodeType nodeType;

  /// The key identifying this tree node.
  final StateKey key;

  /// The parent node of this true node. Returns `null` if this is a root node.
  final TreeNode? parent;

  /// The child nodes of this node. The list is empty for leaf nodes.
  final List<TreeNode> children = [];

  /// Function to identify the child node that should be entered, if this node is entered. Returns
  /// `null` if this node does not have any children.
  final GetInitialChild? getInitialChild;

  /// Lazily computed tree state for this node
  final Lazy<TreeState> _lazyState;

  // Codec to be used for encoding/decoding state data for this node. Will be null if this is not a
  // node for a data state, or if the state tree was built without serialization support.
  final StateDataCodec? dataCodec;

  TreeNode(
    this.nodeType,
    this.key,
    this.parent,
    StateCreator createState,
    this.dataCodec, [
    this.getInitialChild,
  ]) : _lazyState = Lazy<TreeState>(() => createState(key));

  bool get isRoot => nodeType == NodeType.rootNode;
  bool get isLeaf => nodeType == NodeType.leafNode || nodeType == NodeType.finalLeafNode;
  bool get isInterior => nodeType == NodeType.interiorNode;
  bool get isFinalLeaf => nodeType == NodeType.finalLeafNode;

  /// The [TreeState] for this node.
  TreeState get state => _lazyState.value;

  /// The [DataValue] of the [DataTreeState] for this node, or `null` if [state] is not a
  /// [DataTreeState].
  DataValue? get data {
    var s = state;
    return s is DataTreeState ? s.data : null;
  }

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
      var state = _lazyState.value;
      if (state.onDispose != null) {
        state.onDispose!();
      }
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
    return selfAndAncestors().firstWhereOrNull((n) => n.data is DataValue<D>);
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

  DataValue<D>? selfOrAncestorDataValue<D>({StateKey? key, bool throwIfNotFound = false}) {
    var typeofDIsObjectOrDynamic = isTypeOf<Object, D>() || isTypeOf<dynamic, D>();
    // If requested type was Object, then we can't meaningfully search by type. So we can only
    // search by key, and if no key was specified, then we assume the current leaf.
    key = key ?? (typeofDIsObjectOrDynamic ? this.key : null);
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
