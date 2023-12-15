import 'package:collection/collection.dart';

import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/data_value.dart';
import 'package:tree_state_machine/src/machine/utility.dart';

enum NodeType { root, interior, leaf }

sealed class TreeNodeInfo {
  /// The key identifying this tree node.
  StateKey get key;

  StateDataCodec<dynamic>? get dataCodec;

  /// Application provided metadata associated with the state.
  Map<String, Object> get metadata;

  List<TreeStateFilter> get filters;
}

sealed class CompositeNodeInfo2 extends TreeNodeInfo {
  List<TreeNode> get children;
  GetInitialChild get getInitialChild;
}

sealed class RootNodeInfo2 extends CompositeNodeInfo2 {}

sealed class InteriorNodeInfo2 extends CompositeNodeInfo2 {
  CompositeNodeInfo2 get parent;
}

sealed class LeafNodeInfo2 extends TreeNodeInfo {
  CompositeNodeInfo2 get parent;
  bool get isFinalState;
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

  /// The [TreeState] for this node.
  TreeState get state => _lazyState.value;

  /// The [DataValue] of the [DataTreeState] for this node, or `null` if [state] is not a
  /// [DataTreeState].
  DataValue<dynamic>? get data {
    var s = state;
    return s is DataTreeState ? s.data : null;
  }

  void dispose() {
    if (_lazyState.hasValue) {
      _lazyState.value.dispose();
    }
  }
}

sealed class CompositeTreeNode extends TreeNode implements CompositeNodeInfo2 {
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
}

abstract interface class ChildNodeInfo2 {
  TreeNode get parent;
}

final class RootTreeNode extends CompositeTreeNode implements RootNodeInfo2 {
  RootTreeNode(
    super.key,
    super.createState, {
    required super.getInitialChild,
    required super.children,
    super.dataCodec,
    super.filters,
    super.metadata,
  });
}

final class InteriorTreeNode extends CompositeTreeNode
    implements InteriorNodeInfo2 {
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

  @override
  final CompositeTreeNode parent;
}

final class LeafTreeNode extends TreeNode implements LeafNodeInfo2 {
  LeafTreeNode(
    super.key,
    super.createState, {
    required this.parent,
    required this.isFinalState,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  @override
  final CompositeTreeNode parent;

  @override
  final bool isFinalState;
}

/// Describes the positioning of a tree state within a state tree.
// abstract class TreeNodeInfo {
//   /// The type of this tree node.
//   NodeType get nodeType;

//   /// The key identifying this tree node.
//   StateKey get key;

//   /// The parent node of this true node. Returns `null` if this is a root node.
//   TreeNodeInfo? get parent;

//   /// Application provided metadata associated with the state.
//   Map<String, Object> get metadata;

//   /// The child nodes of this node. The list is empty for leaf nodes.
//   ///
//   /// This list is unmodifiable.
//   List<TreeNodeInfo> get children;

//   /// Indicates if the tree state of this node is a final state.
//   bool get isFinal;
// }

// /// A node within a state tree.
// ///
// /// While a [TreeState] defines the message processing behavior of a state, it does not model the
// /// location of the state within a state tree (that is, a [TreeState] does not directly know its
// /// parent or child states). Instead, [TreeNode] composes together a tree state along with
// /// information about the location of the node with the tree.
// class TreeNode implements TreeNodeInfo {
//   TreeNode(
//     this.key, {
//     required StateCreator createState,
//     this.parent,
//     this.getInitialChild,
//     this.isFinal = false,
//     this.dataCodec,
//     List<TreeStateFilter> filters = const [],
//     Map<String, Object> metadata = const {},
//     List<TreeNode> children = const [],
//   })  : _children = children, // TODO make this lazy
//         _lazyState = Lazy<TreeState>(() => createState(key)),
//         filters = List.unmodifiable(List.of(filters)),
//         metadata = Map.unmodifiable(Map.of(metadata));

//   /// The type of this tree node.
//   @override
//   NodeType get nodeType => switch (this) {
//         _ when parent == null => NodeType.root,
//         _ when children.isNotEmpty => NodeType.interior,
//         //_ when isFinal => NodeType.finalLeafNode,
//         _ => NodeType.leaf
//       };

//   /// The key identifying this tree node.
//   @override
//   final StateKey key;

//   /// The parent node of this true node. Returns `null` if this is a root node.
//   @override
//   final TreeNode? parent;

//   /// The child nodes of this node. The list is empty for leaf nodes.
//   final List<TreeNode> _children;

//   @override
//   late final List<TreeNode> children = UnmodifiableListView(_children);

//   /// Function to identify the child node that should be entered, if this node is entered. Returns
//   /// `null` if this node does not have any children.
//   final GetInitialChild? getInitialChild;

//   // Codec to be used for encoding/decoding state data for this node. Will be null if this is not a
//   // node for a data state, or if the state tree was built without serialization support.
//   final StateDataCodec<dynamic>? dataCodec;

//   /// Lazily computed tree state for this node
//   final Lazy<TreeState> _lazyState;

//   /// Filters for this node. When available, these filters are invoked, in the order represented by
//   /// this list, in lieu of node handlers.
//   final List<TreeStateFilter> filters;

//   @override
//   final bool isFinal;

//   @override
//   final Map<String, Object> metadata;

//   bool get isRoot => nodeType == NodeType.root;
//   bool get isLeaf => nodeType == NodeType.leaf;
//   bool get isInterior => nodeType == NodeType.interior;
//   bool get isFinalLeaf => isFinal && nodeType == NodeType.leaf;

//   /// The [TreeState] for this node.
//   TreeState get state => _lazyState.value;

//   /// The [DataValue] of the [DataTreeState] for this node, or `null` if [state] is not a
//   /// [DataTreeState].
//   DataValue<dynamic>? get data {
//     var s = state;
//     return s is DataTreeState ? s.data : null;
//   }

//   /// Lazily-compute the self-and-ancestor nodes of this node.
//   ///
//   /// The first node in the list is this node, and the last is the root node.
//   Iterable<TreeNode> selfAndAncestors() sync* {
//     yield this;
//     yield* ancestors();
//   }

//   /// Lazily-compute the ancestor nodes of this node.
//   ///
//   /// The first node in the list is the parent of this node, and the last is the root node.
//   Iterable<TreeNode> ancestors() sync* {
//     var nextAncestor = parent;
//     while (nextAncestor != null) {
//       yield nextAncestor;
//       nextAncestor = nextAncestor.parent;
//     }
//   }

//   void dispose() {
//     if (_lazyState.hasValue) {
//       _lazyState.value.dispose();
//     }
//   }
// }

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
    return selfAndAncestors()
        .firstWhereOrNull((n) => n.data is DataValue<D> ? true : false);
  }

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

  DataValue<D>? selfOrAncestorDataValue<D>(
      {DataStateKey<D>? key, bool throwIfNotFound = false}) {
    // We cant search
    if (isTypeOfExact<void, D>()) return null;

    var typeofDIsObjectOrDynamic =
        isTypeOfExact<Object, D>() || isTypeOfExact<dynamic, D>();
    // If requested type was Object, then we can't meaningfully search by type. So we can only
    // search by key, and if no key was specified, then we assume the current leaf.
    key = key ??
        (typeofDIsObjectOrDynamic
            ? (switch (this.key) {
                DataStateKey<D>() => this.key as DataStateKey<D>,
                _ => null
              })
            : null);
    var node =
        key != null ? selfOrAncestorWithKey(key) : selfOrAncestorWithData<D>();
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
