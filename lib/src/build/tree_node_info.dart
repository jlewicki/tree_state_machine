import 'dart:collection';

import 'package:tree_state_machine/tree_state_machine.dart';

/// Provides information about how a tree node should be built.
///
/// Pattern-match against subclasses to obtain additional information about the
/// node.
sealed class TreeNodeInfo {
  TreeNodeInfo(
    this.key,
    this.createState, {
    this.dataCodec,
    List<TreeStateFilter> filters = const [],
    Map<String, Object> metadata = const {},
  })  : filters = List.unmodifiable(filters),
        metadata = Map.unmodifiable(metadata);

  /// Identifies the node to be built.
  final StateKey key;

  /// A factory function that can create the [TreeState] that defines the
  /// behavior of the node when it is an active state in a state machine.
  final StateCreator createState;

  /// The [StateDataCodec] that should be used to serialize and deserialize any
  /// state data associated with this node.
  final StateDataCodec<dynamic>? dataCodec;

  /// An unmodifiable list of [TreeStateFilter]s that should intercept the
  /// message and transition handlers of the tree state for this node.
  ///
  /// The filters should be applied in the order they occur in this list.
  final List<TreeStateFilter> filters;

  /// An unmodifiable map of application-provided metadata associated with this
  /// node.
  final Map<String, Object> metadata;
}

/// Provides information about how a composite tree node should be built. A
/// composite node is a node with child nodes.
///
/// Pattern-match against subclasses to obtain additional information about the
/// node.
sealed class CompositeNodeInfo extends TreeNodeInfo {
  CompositeNodeInfo(
    super.key,
    super.createState, {
    required List<TreeNodeInfo> children,
    required this.initialChild,
    super.dataCodec,
    super.filters,
    super.metadata,
  }) : children = UnmodifiableListView(children);

  /// Unmodifiable list of the child nodes of this node.
  final List<TreeNodeInfo> children;

  /// A function that can select the initial child state to enter when the state
  /// is entered.
  final GetInitialChild initialChild;
}

/// Provides a description of how the root node of a state tree should be built.
final class RootNodeInfo extends CompositeNodeInfo {
  RootNodeInfo(
    super.key,
    super.createState, {
    required super.children,
    required super.initialChild,
    super.dataCodec,
    super.filters,
    super.metadata,
  });
}

/// Provides a description of how an interior node of a state tree should be
/// built. An interior node has both a parent node and child nodes.
final class InteriorNodeInfo extends CompositeNodeInfo {
  InteriorNodeInfo(
    super.key,
    super.createState, {
    required this.parent,
    required super.children,
    required super.initialChild,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  /// The parent node of this node.
  final TreeNodeInfo parent;
}

/// Provides a description of how a leaf node of a state tree should be built. A
/// leaf node has a parent node, but no children.
///
/// The current state of a [TreeStateMachine] is always a leaf node.
final class LeafNodeInfo extends TreeNodeInfo {
  LeafNodeInfo(
    super.key,
    super.createState, {
    required this.parent,
    required this.isFinalState,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  /// The parent node of this node.
  final TreeNodeInfo parent;

  /// Indicates if this leaf node represents a final state.
  final bool isFinalState;
}

/// Adds methods to [TreeNodeInfo] for navigating ancestor and descendant nodes.
extension TreeNodeInfoNavigationExtension on TreeNodeInfo {
  /// The parent node of this node, or `null` if it is a root node.
  TreeNodeInfo? parent() {
    return switch (this) {
      LeafNodeInfo(parent: var p) => p,
      InteriorNodeInfo(parent: var p) => p,
      _ => null
    };
  }

  /// Returns the root ancestor node of this node, or this node itself if it is
  /// a root node.
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

  /// The child nodes of this node.
  Iterable<TreeNodeInfo> children() {
    return switch (this) {
      CompositeNodeInfo(children: var c) => c,
      _ => const <TreeNodeInfo>[],
    };
  }

  /// Lazily-computes the descendant nodes of this node, in depth first order
  Iterable<TreeNodeInfo> descendants() sync* {
    for (var child in children()) {
      yield child;
      yield* child.descendants();
    }
  }

  /// Lazily-computes the self-and-descendant nodes of this node, in depth-first
  /// order
  Iterable<TreeNodeInfo> selfAndDescendants() sync* {
    yield this;
    yield* descendants();
  }

  /// Lazily-computes the descendant leaf nodes of this node.
  Iterable<LeafNodeInfo> leaves() {
    return selfAndDescendants().whereType<LeafNodeInfo>();
  }
}
