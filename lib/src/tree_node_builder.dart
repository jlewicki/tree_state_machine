import 'dart:collection';

import 'data_provider.dart';
import 'tree_node.dart';
import 'tree_state.dart';

abstract class NodeBuilder<N extends TreeNode> {
  N build(TreeBuildContext context);
}

class TreeBuildContext {
  final TreeNode parentNode;
  final HashMap<StateKey, TreeNode> nodes;
  final ObservableData<Object> currentLeafData;

  TreeBuildContext._(this.parentNode, this.nodes, this.currentLeafData);

  factory TreeBuildContext(ObservableData<Object> currentLeafData, [TreeNode parentNode]) =>
      TreeBuildContext._(parentNode, HashMap(), currentLeafData);

  TreeBuildContext childContext(TreeNode newParentNode) =>
      TreeBuildContext._(newParentNode, nodes, currentLeafData);

  void addNode(TreeNode node) {
    if (nodes.containsKey(node.key)) {
      final msg = 'A state with key ${node.key} has already been added to the state tree.';
      throw ArgumentError.value(node, 'node', msg);
    }
    nodes[node.key] = node;
  }
}

RootNode buildRoot<T extends TreeState>(
  TreeBuildContext ctx,
  StateKey key,
  RootNode Function(StateKey) createNode,
  Iterable<NodeBuilder<ChildNode>> children,
  InitialChild initialChild,
  Iterable<NodeBuilder<FinalNode>> finalStates,
) {
  if (ctx.parentNode != null) {
    throw ArgumentError.value(ctx, 'ctx', 'Unexpected parent node for root node');
  }
  final nodeKey = key ?? StateKey.forState<T>();
  final root = createNode(nodeKey);
  final childContext = ctx.childContext(root);
  root.children.addAll(children.map((childBuilder) => childBuilder.build(childContext)));
  if (finalStates != null) {
    root.children.addAll(finalStates.map((childBuilder) => childBuilder.build(childContext)));
  }
  ctx.addNode(root);
  return root;
}

InteriorNode buildInterior<T extends TreeState>(
  TreeBuildContext ctx,
  StateKey key,
  InteriorNode Function(StateKey) createNode,
  Iterable<NodeBuilder<ChildNode>> children,
) {
  final nodeKey = key ?? StateKey.forState<T>();
  final interior = createNode(nodeKey);
  final childContext = ctx.childContext(interior);
  interior.children.addAll(children.map((childBuilder) => childBuilder.build(childContext)));
  ctx.addNode(interior);
  return interior;
}

LeafNode buildLeaf<T extends TreeState>(
  TreeBuildContext ctx,
  StateKey key,
  LeafNode Function(StateKey) createNode,
) {
  final nodeKey = key ?? StateKey.forState<T>();
  final leaf = createNode(nodeKey);
  ctx.addNode(leaf);
  return leaf;
}

StateCreator stateCreatorWithDataInitialization<T extends DataTreeState<D>, D>(
  DataStateCreator<T, D> createState,
  DataProvider<D> provider,
  ObservableData<Object> leafData,
) =>
    (key) {
      final state = createState(key);
      if (provider is CurrentLeafDataProvider) {
        (provider as CurrentLeafDataProvider).initializeLeafData(leafData);
      }
      state.initializeDataValue(provider);
      return state;
    };
