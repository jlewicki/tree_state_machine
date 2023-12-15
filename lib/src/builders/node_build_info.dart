part of '../../tree_builders.dart';

class TreeNodeBuildInfo {
  TreeNodeBuildInfo(
    this.key,
    this.createState, {
    this.initialChild,
    this.childBuilders = const [],
    this.isFinalState = false,
    this.dataCodec,
    this.filters = const [],
    this.metadata = const {},
  });

  /// Identifies the node to be built.
  final StateKey key;

  /// A factory function that can create the [TreeState] that defines the behavior of the node.
  final StateCreator createState;
  final List<TreeNodeBuilder> childBuilders;

  /// A function that can select the initial child state to
  final GetInitialChild? initialChild;
  final StateDataCodec<dynamic>? dataCodec;
  final List<TreeStateFilter> filters;
  final Map<String, Object> metadata;
  final bool isFinalState;
}
