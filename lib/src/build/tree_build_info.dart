import 'package:tree_state_machine/tree_state_machine.dart';
import 'package:tree_state_machine/src/machine/tree_state.dart';
import 'package:tree_state_machine/src/machine/tree_node.dart';
import 'package:tree_state_machine/build.dart';

/// Provides information about how a tree node should be built.
///
/// Pattern-match against subclasses to obtain additional information about the node.
sealed class TreeNodeBuildInfo {
  TreeNodeBuildInfo(
    this.key,
    this.createState, {
    this.dataCodec,
    this.filters = const [],
    this.metadata = const {},
  });

  /// Identifies the node to be built.
  final StateKey key;

  /// A factory function that can create the [TreeState] that defines the behavior of the node when
  /// it is an active state in a state machine.
  final StateCreator createState;

  /// The [StateDataCodec] that should be used to serialize and deserialize any state data
  /// associated with this node.
  final StateDataCodec<dynamic>? dataCodec;

  /// An unmodifiable list of [TreeStateFilter]s that should intercept the message and transitions
  /// handlers of the tree state for this node.
  ///
  /// The filters should be applies in the order they occur im this list.
  final List<TreeStateFilter> filters;

  /// An unmodifiable map of Application-specific metadata applied to this node.
  final Map<String, Object> metadata;
}

/// Provides information about how a composite tree node should be built. A composite node is a node
/// with child nodes.
///
/// Pattern-match against subclasses to obtain additional information about the node.
sealed class CompositeNodeBuildInfo extends TreeNodeBuildInfo {
  CompositeNodeBuildInfo(
    super.key,
    super.createState, {
    required this.childBuilders,
    required this.initialChild,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  /// Collecton of [TreeNodeBuilder] functions that can create the child nodes of this node.
  final List<TreeNodeBuilder> childBuilders;

  /// A function that can select the initial child state to enter when the state is entered.
  final GetInitialChild initialChild;
}

/// Provides a description of how the root [TreeNode] of a state tree should be built.
final class RootNodeBuildInfo extends CompositeNodeBuildInfo {
  RootNodeBuildInfo(
    super.key,
    super.createState, {
    required super.childBuilders,
    required super.initialChild,
    super.dataCodec,
    super.filters,
    super.metadata,
  });
}

/// Provides a description of how an interior [TreeNode] of a state tree should be built. An
/// interior node has both a parent node and child nodes.
final class InteriorNodeBuildInfo extends CompositeNodeBuildInfo {
  InteriorNodeBuildInfo(
    super.key,
    super.createState, {
    required this.parent,
    required super.childBuilders,
    required super.initialChild,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  /// Identfies the parent node of this node.
  final StateKey parent;
}

/// Provides a description of how a leaf [TreeNode] of a state tree should be built. A leaf node has
/// a parent node, but no children.
///
/// The current state of a [TreeStateMachine] is always a leaf node.
final class LeafNodeBuildInfo extends TreeNodeBuildInfo {
  LeafNodeBuildInfo(
    super.key,
    super.createState, {
    required this.parent,
    required this.isFinalState,
    super.dataCodec,
    super.filters,
    super.metadata,
  });

  /// Identfies the parent node of this node.
  final StateKey parent;

  /// Indicates if this leaf node represents a final state.
  final bool isFinalState;
}
